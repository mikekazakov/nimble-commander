//
//  FileSearch.cpp
//  Files
//
//  Created by Michael G. Kazakov on 11.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <sys/stat.h>
#include "../../Files/FileWindow.h"
#include "../../Files/SearchInFile.h"
#include "SearchForFiles.h"

static int EncodingFromXAttr(const VFSFilePtr &_f)
{
    char buf[128];
    ssize_t r = _f->XAttrGet("com.apple.TextEncoding", buf, sizeof(buf));
    if(r < 0 || r >= sizeof(buf))
        return encodings::ENCODING_INVALID;
    buf[r] = 0;
    return encodings::FromComAppleTextEncodingXAttr(buf);
}

SearchForFiles::SearchForFiles()
{
    m_Queue->OnDry([=]{
        m_Callback = nullptr;
        m_LookingInCallback = nullptr;
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
        throw logic_error("Filters can't be changed during background search process");
    m_FilterName = _filter;
    // substitute simple requests, like "system" with "*system*":
    if( !FileMask::IsWildCard(m_FilterName->mask) )
        if( auto wild_card = FileMask::ToFilenameWildCard(m_FilterName->mask) )
            m_FilterName->mask = wild_card;
    
    m_FilterNameMask = FileMask(m_FilterName->mask);
}

void SearchForFiles::SetFilterContent(const FilterContent &_filter)
{
    if( IsRunning() )
        throw logic_error("Filters can't be changed during background search process");
    m_FilterContent = _filter;
}

void SearchForFiles::SetFilterSize(const FilterSize &_filter)
{
    if( IsRunning() )
        throw logic_error("Filters can't be changed during background search process");
    if( _filter.min == 0 &&
        _filter.max == numeric_limits<uint64_t>::max())
        return;
    m_FilterSize = _filter;
}

void SearchForFiles::ClearFilters()
{
    if( IsRunning() )
        throw logic_error("Filters can't be changed during background search process");
    m_FilterName = nullopt;
    m_FilterNameMask = nullopt;
    m_FilterContent = nullopt;
    m_FilterSize = nullopt;
}

bool SearchForFiles::Go(const string &_from_path,
                    const VFSHostPtr &_in_host,
                    int _options,
                    FoundCallBack _found_callback,
                    function<void()> _finish_callback,
                    function<void(const char*)> _looking_in_callback
                    )
{
    if( IsRunning() )
        return false;
        
    assert( !m_Callback );
    
    m_Callback = move(_found_callback);
    m_FinishCallback = move(_finish_callback);
    m_LookingInCallback = move(_looking_in_callback);
    m_SearchOptions = _options;
    m_DirsFIFO = {};
    
    m_Queue->Run([=]{
        AsyncProc( _from_path.c_str(), *_in_host );
    });
    
    return true;
}

void SearchForFiles::Stop()
{
    m_Queue->Stop();
}

void SearchForFiles::Wait()
{
    m_Queue->Wait();
}

void SearchForFiles::NotifyLookingIn(const char* _path) const
{
    if( m_LookingInCallback )
        m_LookingInCallback(_path);
}

void SearchForFiles::AsyncProc(const char *_from_path, VFSHost &_in_host)
{
    m_DirsFIFO.emplace(_from_path);
    
    while( !m_DirsFIFO.empty() ) {
        if( m_Queue->IsStopped() )
            break;
        
        string path = move( m_DirsFIFO.front() );
        m_DirsFIFO.pop();
        
        NotifyLookingIn( path.c_str() );
        
        _in_host.IterateDirectoryListing(path.c_str(),
                                      [&](const VFSDirEnt &_dirent)
                                      {
                                          if(m_Queue->IsStopped())
                                              return false;
                                          
                                          string full_path = path;
                                          if(full_path.back() != '/') full_path += '/';
                                          full_path += _dirent.name;
                                          
                                          ProcessDirent(full_path.c_str(),
                                                        path.c_str(),
                                                        _dirent,
                                                        _in_host);
                                          
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
    if(failed_filtering == false && m_FilterContent)
    {
       if(_dirent.type != VFSDirEnt::Reg || !FilterByContent(_full_path, _in_host, content_pos) )
           failed_filtering = true;
    }
    
    if(failed_filtering == false)
        ProcessValidEntry(_full_path, _dir_path, _dirent, _in_host, content_pos);
    
    if( m_SearchOptions & Options::GoIntoSubDirs )
        if( _dirent.type == VFSDirEnt::Dir )
            m_DirsFIFO.emplace(_full_path);
}

bool SearchForFiles::FilterByContent(const char* _full_path, VFSHost &_in_host, CFRange &_r)
{
    assert(m_FilterContent);
    VFSFilePtr file;
    if(_in_host.CreateFile(_full_path, file, 0) != 0)
        return false;
    
    if(file->Open(VFSFlags::OF_Read) != 0)
        return false;
    
    NotifyLookingIn( _full_path );
    
    FileWindow fw;
    if(fw.OpenFile(file) != 0 )
        return false;
    
    int encoding = m_FilterContent->encoding;
    if(int xattr_enc = EncodingFromXAttr(file))
        encoding = xattr_enc;
    
    SearchInFile sif(fw);
    sif.ToggleTextSearch((__bridge CFStringRef)m_FilterContent->text, encoding);
    sif.SetSearchOptions((m_FilterContent->case_sensitive  ? SearchInFile::OptionCaseSensitive   : 0) |
                         (m_FilterContent->whole_phrase    ? SearchInFile::OptionFindWholePhrase : 0) );
    
    
    uint64_t found_pos;
    uint64_t found_len;
    auto result = sif.Search(&found_pos,
                             &found_len,
                             ^bool{
                                 return m_Queue->IsStopped();
                             }
                             );
    if(result == SearchInFile::Result::Found) {
        _r = CFRangeMake(found_pos, found_len);
        return true;
    }
    return false;
}

bool SearchForFiles::FilterByFilename(const char* _filename)
{
    NSString *filename = [NSString stringWithUTF8StringNoCopy:_filename];
    if(filename == nil ||
       m_FilterNameMask->MatchName(filename) == false)
        return false;
    
    return true;
}

void SearchForFiles::ProcessValidEntry(const char* _full_path,
                       const char* _dir_path,
                       const VFSDirEnt &_dirent,
                       VFSHost &_in_host,
                       CFRange _cont_range)
{
    if(m_Callback)
        m_Callback(_dirent.name, _dir_path, _cont_range);
}

bool SearchForFiles::IsRunning() const noexcept
{
    return m_Queue->Empty() == false;
}
