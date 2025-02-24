// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DeletionJob.h"
#include <Utility/PathManip.h>
#include <Utility/NativeFSManager.h>
#include <dirent.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <algorithm>

namespace nc::ops {

static bool IsEAStorage(VFSHost &_host, const std::string &_directory, const char *_filename, uint8_t _unix_type);

DeletionJob::DeletionJob(std::vector<VFSListingItem> _items, DeletionType _type)
{
    m_SourceItems = std::move(_items);
    m_Type = _type;
    if( _type == DeletionType::Trash &&
        !std::ranges::all_of(m_SourceItems, [](auto &i) { return i.Host()->IsNativeFS(); }) )
        throw std::invalid_argument("DeletionJob: invalid work mode for the provided items");
    Statistics().SetPreferredSource(Statistics::SourceType::Items);
}

DeletionJob::~DeletionJob() = default;

void DeletionJob::Perform()
{
    DoScan();

    if( BlockIfPaused(); IsStopped() )
        return;

    DoDelete();
}

void DeletionJob::DoScan()
{
    for( int i = 0, e = static_cast<int>(m_SourceItems.size()); i != e; ++i ) {
        if( BlockIfPaused(); IsStopped() )
            return;

        const auto &item = m_SourceItems[i];
        Statistics().CommitEstimated(Statistics::SourceType::Items, 1);

        if( item.UnixType() == DT_DIR ) {
            m_Paths.push_back(EnsureTrailingSlash(item.Filename()), nullptr);
            SourceItem si;
            si.listing_item_index = i;
            si.filename = &m_Paths.back();
            si.type = m_Type;
            m_Script.emplace(si);

            const auto nonempty_rm = bool(item.Host()->Features() & vfs::HostFeatures::NonEmptyRmDir);
            if( m_Type == DeletionType::Permanent && !nonempty_rm )
                ScanDirectory(item.Path(), i, si.filename);
        }
        else {
            const auto is_ea_storage = IsEAStorage(*item.Host(), item.Directory(), item.FilenameC(), item.UnixType());
            if( !is_ea_storage ) {
                m_Paths.push_back(item.Filename(), nullptr);
                SourceItem si;
                si.listing_item_index = i;
                si.filename = &m_Paths.back();
                si.type = m_Type;
                m_Script.emplace(si);
            }
        }
    }
}

void DeletionJob::ScanDirectory(const std::string &_path,
                                int _listing_item_index,
                                const base::chained_strings::node *_prefix)
{
    auto &vfs = *m_SourceItems[_listing_item_index].Host();

    std::vector<VFSDirEnt> dir_entries;
    const auto it_callback = [&](const VFSDirEnt &_entry) {
        dir_entries.emplace_back(_entry);
        return true;
    };
    while( true ) {
        if( BlockIfPaused(); IsStopped() )
            return;

        if( const std::expected<void, Error> rc = vfs.IterateDirectoryListing(_path, it_callback); rc )
            break;
        else
            switch( m_OnReadDirError(rc.error(), _path, vfs) ) {
                case ReadDirErrorResolution::Retry:
                    continue;
                case ReadDirErrorResolution::Stop:
                    Stop();
                    [[fallthrough]];
                case ReadDirErrorResolution::Skip:
                    return;
            }
    }

    for( const auto &e : dir_entries ) {
        if( BlockIfPaused(); IsStopped() )
            return;

        Statistics().CommitEstimated(Statistics::SourceType::Items, 1);
        if( e.type == DT_DIR ) {
            m_Paths.push_back(EnsureTrailingSlash(e.name), _prefix);
            SourceItem si;
            si.listing_item_index = _listing_item_index;
            si.filename = &m_Paths.back();
            si.type = DeletionType::Permanent;
            m_Script.emplace(si);

            ScanDirectory(EnsureTrailingSlash(_path) + e.name, _listing_item_index, si.filename);
        }
        else {
            const auto is_ea_storage = IsEAStorage(vfs, _path, e.name, static_cast<uint8_t>(e.type));
            if( !is_ea_storage ) {
                m_Paths.push_back(e.name, _prefix);
                SourceItem si;
                si.listing_item_index = _listing_item_index;
                si.filename = &m_Paths.back();
                si.type = DeletionType::Permanent;
                m_Script.emplace(si);
            }
        }
    }
}

void DeletionJob::DoDelete()
{
    while( !m_Script.empty() ) {
        if( BlockIfPaused(); IsStopped() )
            return;

        const auto entry = m_Script.top();
        m_Script.pop();

        const auto path = m_SourceItems[entry.listing_item_index].Directory() + entry.filename->to_str_with_pref();
        const auto &vfs = m_SourceItems[entry.listing_item_index].Host();
        const auto type = entry.type;

        if( type == DeletionType::Permanent ) {
            const auto is_dir = utility::PathManip::HasTrailingSlash(path);
            if( is_dir )
                DoRmDir(path, *vfs);
            else
                DoUnlink(path, *vfs);
        }
        else {
            DoTrash(path, *vfs, entry);
        }
    }
}

bool DeletionJob::DoUnlock(const std::string &_path, VFSHost &_vfs)
{
    while( true ) {
        const std::expected<void, Error> unlock_rc = UnlockItem(_path, _vfs);
        if( unlock_rc )
            return true;
        switch( m_OnUnlockError(unlock_rc.error(), _path, _vfs) ) {
            case DeletionJobCallbacks::UnlockErrorResolution::Retry:
                continue;
            case DeletionJobCallbacks::UnlockErrorResolution::Skip:
                Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
                return false;
            case DeletionJobCallbacks::UnlockErrorResolution::Stop:
                Stop();
                return false;
        }
    }
    return true;
}

void DeletionJob::DoUnlink(const std::string &_path, VFSHost &_vfs)
{
    while( true ) {
        const std::expected<void, Error> rc = _vfs.Unlink(_path);
        if( rc ) {
            Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
            break;
        }
        else if( IsNativeLockedItem(rc.error(), _path, _vfs) ) {
            switch( m_OnLockedItem(rc.error(), _path, _vfs, DeletionType::Permanent) ) {
                case LockedItemResolution::Unlock: {
                    if( !DoUnlock(_path, _vfs) )
                        return;
                    continue;
                }
                case LockedItemResolution::Retry:
                    continue;
                case LockedItemResolution::Skip:
                    Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
                    return;
                case LockedItemResolution::Stop:
                    Stop();
                    return;
            }
        }
        else {
            switch( m_OnUnlinkError(rc.error(), _path, _vfs) ) {
                case UnlinkErrorResolution::Retry:
                    continue;
                case UnlinkErrorResolution::Skip:
                    Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
                    return;
                case UnlinkErrorResolution::Stop:
                    Stop();
                    return;
            }
        }
    }
}

void DeletionJob::DoRmDir(const std::string &_path, VFSHost &_vfs)
{
    while( true ) {
        const std::expected<void, Error> rc = _vfs.RemoveDirectory(_path);
        if( rc ) {
            Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
            break;
        }
        else if( IsNativeLockedItem(rc.error(), _path, _vfs) ) {
            switch( m_OnLockedItem(rc.error(), _path, _vfs, DeletionType::Permanent) ) {
                case LockedItemResolution::Unlock: {
                    if( !DoUnlock(_path, _vfs) )
                        return;
                    continue;
                }
                case LockedItemResolution::Retry:
                    continue;
                case LockedItemResolution::Skip:
                    Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
                    return;
                case LockedItemResolution::Stop:
                    Stop();
                    return;
            }
        }
        else {
            switch( m_OnRmdirError(rc.error(), _path, _vfs) ) {
                case RmdirErrorResolution::Retry:
                    continue;
                case RmdirErrorResolution::Skip:
                    Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
                    return;
                case RmdirErrorResolution::Stop:
                    Stop();
                    return;
            }
        }
    }
}

void DeletionJob::DoTrash(const std::string &_path, VFSHost &_vfs, SourceItem _src)
{
    while( true ) {
        const std::expected<void, nc::Error> result = _vfs.Trash(_path);
        if( result ) {
            Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
        }
        else if( IsNativeLockedItem(result.error(), _path, _vfs) ) {
            switch( m_OnLockedItem(result.error(), _path, _vfs, DeletionType::Trash) ) {
                case LockedItemResolution::Unlock: {
                    if( !DoUnlock(_path, _vfs) )
                        return;
                    continue;
                }
                case LockedItemResolution::Retry:
                    continue;
                case LockedItemResolution::Skip:
                    Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
                    return;
                case LockedItemResolution::Stop:
                    Stop();
                    return;
            }
        }
        else {
            const auto resolution = m_OnTrashError(result.error(), _path, _vfs);
            if( resolution == TrashErrorResolution::Retry ) {
                continue;
            }
            else if( resolution == TrashErrorResolution::Skip ) {
                Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
            }
            else if( resolution == TrashErrorResolution::DeletePermanently ) {
                SourceItem si = _src;
                si.type = DeletionType::Permanent;
                m_Script.emplace(si);
                const auto is_dir = utility::PathManip::HasTrailingSlash(_path);
                if( is_dir )
                    ScanDirectory(_path, si.listing_item_index, si.filename);
            }
            else {
                Stop();
            }
        }
        return;
    }
}

int DeletionJob::ItemsInScript() const
{
    return static_cast<int>(m_Script.size());
}

bool DeletionJob::IsNativeLockedItem(const nc::Error &_err, const std::string &_path, VFSHost &_vfs)
{
    if( _err != Error{Error::POSIX, EPERM} )
        return false;

    if( !_vfs.IsNativeFS() )
        return false;

    const std::expected<VFSStat, Error> st = _vfs.Stat(_path, nc::vfs::Flags::F_NoFollow);
    if( !st )
        return false;

    return st->flags & UF_IMMUTABLE;
}

std::expected<void, Error> DeletionJob::UnlockItem(std::string_view _path, VFSHost &_vfs)
{
    // this is kind of stupid to call stat() essentially twice :-|

    const std::expected<VFSStat, Error> st = _vfs.Stat(_path, vfs::Flags::F_NoFollow);
    if( !st )
        return std::unexpected(st.error());

    const uint32_t flags = (st->flags & ~UF_IMMUTABLE);
    const std::expected<void, Error> chflags_rc = _vfs.SetFlags(_path, flags, vfs::Flags::F_NoFollow);
    return chflags_rc;
}

static bool IsEAStorage(VFSHost &_host, const std::string &_directory, const char *_filename, uint8_t _unix_type)
{
    if( _unix_type != DT_REG || !_host.IsNativeFS() || _filename[0] != '.' || _filename[1] != '_' || _filename[2] == 0 )
        return false;

    char origin_file_path[MAXPATHLEN];
    strcpy(origin_file_path, _directory.c_str());
    if( !utility::PathManip::HasTrailingSlash(origin_file_path) )
        strcat(origin_file_path, "/");
    strcat(origin_file_path, _filename + 2);
    return _host.Exists(origin_file_path);
}

} // namespace nc::ops
