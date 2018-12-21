// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/stat.h>
#include "FileWindow.h"
#include "SearchInFile.h"
#include "SearchForFiles.h"

static int EncodingFromXAttr(const VFSFilePtr &_f)
{
    char buf[128];
    ssize_t r = _f->XAttrGet("com.apple.TextEncoding", buf, sizeof(buf));
    if(r < 0 || r >= (ssize_t)sizeof(buf))
        return encodings::ENCODING_INVALID;
    buf[r] = 0;
    return encodings::FromComAppleTextEncodingXAttr(buf);
}

SearchForFiles::SearchForFiles()
{
    m_Queue.SetOnDry([=]{
        m_Callback = nullptr;
        m_LookingInCallback = nullptr;
        m_SpawnArchiveCallback = nullptr;
        m_SearchOptions = 0;
        if( m_FinishCallback ) {
            m_FinishCallback();
            m_FinishCallback = nullptr;
        }
    });
}

SearchForFiles::~SearchForFiles()
{
    Wait();
}

void SearchForFiles::SetFilterName(const FilterName &_filter)
{
    if( IsRunning() )
        throw std::logic_error("Filters can't be changed during background search process");
    m_FilterName = _filter;
    // substitute simple requests, like "system" with "*system*":
    if( !nc::utility::FileMask::IsWildCard(m_FilterName->mask) )
        m_FilterName->mask = nc::utility::FileMask::ToFilenameWildCard(m_FilterName->mask);
    
    m_FilterNameMask = nc::utility::FileMask(m_FilterName->mask);
}

void SearchForFiles::SetFilterContent(const FilterContent &_filter)
{
    if( IsRunning() )
        throw std::logic_error("Filters can't be changed during background search process");
    m_FilterContent = _filter;
}

void SearchForFiles::SetFilterSize(const FilterSize &_filter)
{
    if( IsRunning() )
        throw std::logic_error("Filters can't be changed during background search process");
    if( _filter.min == 0 &&
       _filter.max == std::numeric_limits<uint64_t>::max())
        return;
    m_FilterSize = _filter;
}

void SearchForFiles::ClearFilters()
{
    if( IsRunning() )
        throw std::logic_error("Filters can't be changed during background search process");
    m_FilterName = std::nullopt;
    m_FilterNameMask = std::nullopt;
    m_FilterContent = std::nullopt;
    m_FilterSize = std::nullopt;
}

bool SearchForFiles::Go(const std::string &_from_path,
                        const VFSHostPtr &_in_host,
                        int _options,
                        FoundCallback _found_callback,
                        std::function<void()> _finish_callback,
                        LookingInCallback _looking_in_callback,
                        SpawnArchiveCallback _spawn_archive_callback
                        )
{
    if( IsRunning() )
        return false;
        
    assert( !m_Callback );
    
    m_Callback = move(_found_callback);
    m_FinishCallback = move(_finish_callback);
    m_SpawnArchiveCallback = move(_spawn_archive_callback);
    m_LookingInCallback = move(_looking_in_callback);
    m_SearchOptions = _options;
    m_DirsFIFO = {};
    
    m_Queue.Run([=]{
        AsyncProc( _from_path.c_str(), *_in_host );
    });
    
    return true;
}

void SearchForFiles::Stop()
{
    m_Queue.Stop();
}

bool SearchForFiles::IsStopped()
{
    return m_Queue.IsStopped();
}

void SearchForFiles::Wait()
{
    m_Queue.Wait();
}

void SearchForFiles::NotifyLookingIn(const char* _path, VFSHost &_in_host) const
{
    if( m_LookingInCallback )
        m_LookingInCallback( _path, _in_host );
}

void SearchForFiles::AsyncProc(const char *_from_path, VFSHost &_in_host)
{
    m_DirsFIFO.emplace(_in_host.SharedPtr(), _from_path);
    
    while( !m_DirsFIFO.empty() ) {
        if( m_Queue.IsStopped() )
            break;
        
        auto path = std::move( m_DirsFIFO.front() );
        m_DirsFIFO.pop();
        
        NotifyLookingIn( path.Path().c_str(), *path.Host() );
        
        path.Host()->IterateDirectoryListing(path.Path().c_str(),
                                      [&](const VFSDirEnt &_dirent)
                                      {
                                          if(m_Queue.IsStopped())
                                              return false;
                                          
                                          std::string full_path = path.Path();
                                          if(full_path.back() != '/') full_path += '/';
                                          full_path += _dirent.name;
                                          
                                          ProcessDirent(full_path.c_str(),
                                                        path.Path().c_str(),
                                                        _dirent,
                                                        *path.Host());
                                          
                                          return true;
                                      });
    }
}

void SearchForFiles::ProcessDirent(const char* _full_path,
                                   const char* _dir_path,
                                   const VFSDirEnt &_dirent,
                                   VFSHost &_in_host
                                   )
{
    bool failed_filtering = false;
    
    // Filter by being a directory
    if(failed_filtering == false &&
       _dirent.type == VFSDirEnt::Dir &&
       (m_SearchOptions & Options::SearchForDirs) == 0 )
        failed_filtering = true;

    // Filter by being a reg or link
    if(failed_filtering == false &&
       (_dirent.type == VFSDirEnt::Reg || _dirent.type == VFSDirEnt::Link ) &&
       (m_SearchOptions & Options::SearchForFiles) == 0 )
        failed_filtering = true;
    
    // Filter by filename
    if(failed_filtering == false &&
       m_FilterNameMask &&
       !FilterByFilename(_dirent.name)
       )
        failed_filtering = true;
    
    // Filter by filesize
    if(failed_filtering == false && m_FilterSize) {
        if(_dirent.type == VFSDirEnt::Reg) {
            VFSStat st;
            if(_in_host.Stat(_full_path, st, 0, 0) == 0) {
                if(st.size < m_FilterSize->min ||
                   st.size > m_FilterSize->max )
                    failed_filtering = true;
            }
            else
                failed_filtering = true;
        }
        else
            failed_filtering = true;
    }
    
    // Filter by file content
    CFRange content_pos{-1, 0};
    if(failed_filtering == false && m_FilterContent) {
       if(_dirent.type != VFSDirEnt::Reg || !FilterByContent(_full_path, _in_host, content_pos) )
           failed_filtering = true;
    }
    
    if(failed_filtering == false)
        ProcessValidEntry(_full_path, _dir_path, _dirent, _in_host, content_pos);
    
    if( m_SearchOptions & Options::GoIntoSubDirs )
        if( _dirent.type == VFSDirEnt::Dir )
            m_DirsFIFO.emplace(_in_host.SharedPtr(), _full_path);
    
    if( m_SearchOptions & Options::LookInArchives )
        if( _dirent.type == VFSDirEnt::Reg && m_SpawnArchiveCallback )
            if( auto archive_host = m_SpawnArchiveCallback(_full_path, _in_host) )
                m_DirsFIFO.emplace(archive_host, "/");
}

bool SearchForFiles::FilterByContent(const char* _full_path, VFSHost &_in_host, CFRange &_r)
{
    assert(m_FilterContent);
    VFSFilePtr file;
    if(_in_host.CreateFile(_full_path, file, 0) != 0)
        return false;
    
    if(file->Open(VFSFlags::OF_Read) != 0)
        return false;
    
    NotifyLookingIn( _full_path, _in_host );
    
    FileWindow fw;
    if(fw.OpenFile(file) != 0 )
        return false;
    
    int encoding = m_FilterContent->encoding;
    if(int xattr_enc = EncodingFromXAttr(file))
        encoding = xattr_enc;
    
    SearchInFile sif(fw);
    
    CFStringRef request = CFStringCreateWithUTF8StdString(m_FilterContent->text);
    sif.ToggleTextSearch(request, encoding);
    CFRelease(request);
    sif.SetSearchOptions((m_FilterContent->case_sensitive  ? SearchInFile::OptionCaseSensitive   : 0) |
                         (m_FilterContent->whole_phrase    ? SearchInFile::OptionFindWholePhrase : 0) );
    
    
    uint64_t found_pos;
    uint64_t found_len;
    auto result = sif.Search(&found_pos,
                             &found_len,
                             [=]{ return m_Queue.IsStopped(); }
                             );
    if(result == SearchInFile::Result::Found) {
        _r = CFRangeMake(found_pos, found_len);
        return true;
    }
    return false;
}

bool SearchForFiles::FilterByFilename(const char* _filename) const
{
    return m_FilterNameMask->MatchName(_filename);
}

void SearchForFiles::ProcessValidEntry(const char* _full_path,
                       const char* _dir_path,
                       const VFSDirEnt &_dirent,
                       VFSHost &_in_host,
                       CFRange _cont_range)
{
    if(m_Callback)
        m_Callback(_dirent.name, _dir_path, _in_host, _cont_range);
}

bool SearchForFiles::IsRunning() const noexcept
{
    return m_Queue.Empty() == false;
}
