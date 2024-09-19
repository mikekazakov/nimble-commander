// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SearchForFiles.h"
#include <sys/stat.h>
#include <VFS/FileWindow.h>
#include <VFS/SearchInFile.h>

namespace nc::vfs {

static utility::Encoding EncodingFromXAttr(const VFSFilePtr &_f)
{
    char buf[128];
    const ssize_t r = _f->XAttrGet("com.apple.TextEncoding", buf, sizeof(buf));
    if( r < 0 || r >= static_cast<ssize_t>(sizeof(buf)) )
        return utility::Encoding::ENCODING_INVALID;
    buf[r] = 0;
    return utility::FromComAppleTextEncodingXAttr(buf);
}

SearchForFiles::SearchForFiles()
{
    m_Queue.SetOnDry([this] {
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

void SearchForFiles::SetFilterName(utility::FileMask _filter)
{
    if( IsRunning() )
        throw std::logic_error("Filters can't be changed during background search process");

    m_FilterName = std::move(_filter);
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
    if( _filter.min == 0 && _filter.max == std::numeric_limits<uint64_t>::max() )
        return;
    m_FilterSize = _filter;
}

void SearchForFiles::ClearFilters()
{
    if( IsRunning() )
        throw std::logic_error("Filters can't be changed during background search process");
    m_FilterName = {};
    m_FilterContent = std::nullopt;
    m_FilterSize = std::nullopt;
}

bool SearchForFiles::Go(const std::string &_from_path,
                        const VFSHostPtr &_in_host,
                        int _options,
                        FoundCallback _found_callback,
                        std::function<void()> _finish_callback,
                        LookingInCallback _looking_in_callback,
                        SpawnArchiveCallback _spawn_archive_callback)
{
    if( IsRunning() )
        return false;

    assert(!m_Callback);

    m_Callback = std::move(_found_callback);
    m_FinishCallback = std::move(_finish_callback);
    m_SpawnArchiveCallback = std::move(_spawn_archive_callback);
    m_LookingInCallback = std::move(_looking_in_callback);
    m_SearchOptions = _options;
    m_DirsFIFO = {};

    m_Queue.Run([=, this] { AsyncProc(_from_path.c_str(), *_in_host); });

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

void SearchForFiles::NotifyLookingIn(const char *_path, VFSHost &_in_host) const
{
    if( m_LookingInCallback )
        m_LookingInCallback(_path, _in_host);
}

void SearchForFiles::AsyncProc(const char *_from_path, VFSHost &_in_host)
{
    m_DirsFIFO.emplace(_in_host.SharedPtr(), _from_path);

    while( !m_DirsFIFO.empty() ) {
        if( m_Queue.IsStopped() )
            break;

        auto path = std::move(m_DirsFIFO.front());
        m_DirsFIFO.pop();

        NotifyLookingIn(path.Path().c_str(), *path.Host());

        path.Host()->IterateDirectoryListing(path.Path().c_str(), [&](const VFSDirEnt &_dirent) {
            if( m_Queue.IsStopped() )
                return false;

            std::string full_path = path.Path();
            if( full_path.back() != '/' )
                full_path += '/';
            full_path += _dirent.name;

            ProcessDirent(full_path.c_str(), path.Path().c_str(), _dirent, *path.Host());

            return true;
        });
    }
}

void SearchForFiles::ProcessDirent(const char *_full_path,
                                   const char *_dir_path,
                                   const VFSDirEnt &_dirent,
                                   VFSHost &_in_host)
{
    bool failed_filtering = false;

    // Filter by being a directory
    if( failed_filtering == false && _dirent.type == VFSDirEnt::Dir && (m_SearchOptions & Options::SearchForDirs) == 0 )
        failed_filtering = true;

    // Filter by being a reg or link
    if( failed_filtering == false && (_dirent.type == VFSDirEnt::Reg || _dirent.type == VFSDirEnt::Link) &&
        (m_SearchOptions & Options::SearchForFiles) == 0 )
        failed_filtering = true;

    // Filter by filename
    if( failed_filtering == false && !m_FilterName.IsEmpty() && !FilterByFilename(_dirent.name) )
        failed_filtering = true;

    // Filter by filesize
    if( failed_filtering == false && m_FilterSize ) {
        if( _dirent.type == VFSDirEnt::Reg ) {
            VFSStat st;
            if( _in_host.Stat(_full_path, st, 0, nullptr) == 0 ) {
                if( st.size < m_FilterSize->min || st.size > m_FilterSize->max )
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
    if( failed_filtering == false && m_FilterContent ) {
        if( _dirent.type != VFSDirEnt::Reg || !FilterByContent(_full_path, _in_host, content_pos) )
            failed_filtering = true;
    }

    if( failed_filtering == false )
        ProcessValidEntry(_full_path, _dir_path, _dirent, _in_host, content_pos);

    if( m_SearchOptions & Options::GoIntoSubDirs )
        if( _dirent.type == VFSDirEnt::Dir )
            m_DirsFIFO.emplace(_in_host.SharedPtr(), _full_path);

    if( m_SearchOptions & Options::LookInArchives )
        if( _dirent.type == VFSDirEnt::Reg && m_SpawnArchiveCallback )
            if( auto archive_host = m_SpawnArchiveCallback(_full_path, _in_host) )
                m_DirsFIFO.emplace(archive_host, "/");
}

bool SearchForFiles::FilterByContent(const char *_full_path, VFSHost &_in_host, CFRange &_r)
{
    assert(m_FilterContent);
    _r = CFRangeMake(-1, 0);

    VFSFilePtr file;
    if( _in_host.CreateFile(_full_path, file, nullptr) != 0 )
        return false;

    if( file->Open(VFSFlags::OF_Read) != 0 )
        return false;

    NotifyLookingIn(_full_path, _in_host);

    nc::vfs::FileWindow fw;
    if( fw.Attach(file) != 0 )
        return false;

    utility::Encoding encoding = m_FilterContent->encoding;
    if( const utility::Encoding xattr_enc = EncodingFromXAttr(file); xattr_enc != utility::Encoding::ENCODING_INVALID )
        encoding = xattr_enc;

    using nc::vfs::SearchInFile;
    SearchInFile sif(fw);

    const base::CFString request{m_FilterContent->text};
    sif.ToggleTextSearch(*request, encoding);
    const auto search_options = [&] {
        auto options = SearchInFile::Options::None;
        if( m_FilterContent->case_sensitive )
            options |= SearchInFile::Options::CaseSensitive;
        if( m_FilterContent->whole_phrase )
            options |= SearchInFile::Options::FindWholePhrase;
        return options;
    }();
    sif.SetSearchOptions(search_options);

    const auto result = sif.Search([this] { return m_Queue.IsStopped(); });
    if( result.response == SearchInFile::Response::Found ) {
        _r = CFRangeMake(result.location->offset, result.location->bytes_len);
        return m_FilterContent->not_containing == false;
    }
    if( result.response == SearchInFile::Response::NotFound ) {
        return m_FilterContent->not_containing == true;
    }

    return false;
}

bool SearchForFiles::FilterByFilename(const char *_filename) const
{
    return m_FilterName.MatchName(_filename);
}

void SearchForFiles::ProcessValidEntry([[maybe_unused]] const char *_full_path,
                                       const char *_dir_path,
                                       const VFSDirEnt &_dirent,
                                       VFSHost &_in_host,
                                       CFRange _cont_range)
{
    if( m_Callback ) // change to assert
        m_Callback(_dirent.name, _dir_path, _in_host, _cont_range);
}

bool SearchForFiles::IsRunning() const noexcept
{
    return m_Queue.Empty() == false;
}

} // namespace nc::vfs
