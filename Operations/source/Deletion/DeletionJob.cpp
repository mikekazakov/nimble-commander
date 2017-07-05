#include "DeletionJob.h"
#include <Utility/PathManip.h>
#include <Utility/NativeFSManager.h>

namespace nc::ops {

static bool IsEAStorage(VFSHost &_host,
                        const string &_directory,
                        const char *_filename,
                        uint8_t _unix_type);

DeletionJob::DeletionJob( vector<VFSListingItem> _items, DeletionType _type )
{
    m_SourceItems = move(_items);
    m_Type = _type;
    if( _type == DeletionType::Trash && !all_of(begin(m_SourceItems), end(m_SourceItems),
        [](auto &i) { return i.Host()->IsNativeFS(); } ) )
        throw invalid_argument("DeletionJob: invalid work mode for the provided items");
    Statistics().SetPreferredSource( Statistics::SourceType::Items );
}

DeletionJob::~DeletionJob()
{
}

void DeletionJob::Perform()
{
    DoScan();
    
    if( BlockIfPaused(); IsStopped() )
        return;

    DoDelete();
}

void DeletionJob::DoScan()
{
    for( int i = 0, e = (int)m_SourceItems.size(); i != e; ++i ) {
        const auto &item = m_SourceItems[i];
        Statistics().CommitEstimated(Statistics::SourceType::Items, 1);

        if( item.UnixType() == DT_DIR ) {
            m_Paths.push_back( EnsureTrailingSlash(item.Filename()), nullptr );
            SourceItem si;
            si.listing_item_index = i;
            si.filename = &m_Paths.back();
            si.type = m_Type;
            m_Script.emplace(si);
            
            if( m_Type != DeletionType::Trash )
                ScanDirectory(item.Path(), i, si.filename);
        }
        else {
            const auto is_ea_storage = IsEAStorage(*item.Host(),
                                                   item.Directory(),
                                                   item.Name(),
                                                   item.UnixType());
            if( !is_ea_storage ) {
                m_Paths.push_back( item.Filename(), nullptr );
                SourceItem si;
                si.listing_item_index = i;
                si.filename = &m_Paths.back();
                si.type = m_Type;
                m_Script.emplace(si);
            }
        }
    }
}

void DeletionJob::ScanDirectory(const string &_path,
                                int _listing_item_index,
                                const chained_strings::node *_prefix)
{
    auto &vfs = *m_SourceItems[_listing_item_index].Host();

    vector<VFSDirEnt> dir_entries;
    const auto rc = vfs.IterateDirectoryListing(_path.c_str(), [&](const VFSDirEnt &_entry){
        dir_entries.emplace_back(_entry);
        return true;
    });
    
    if( rc != VFSError::Ok ) {
        const auto resolution = m_OnReadDirError(rc, _path, vfs);
        if( resolution == ReadDirErrorResolution::Stop )
            Stop();
        return;
    }
    
    for( const auto &e: dir_entries ) {
        Statistics().CommitEstimated(Statistics::SourceType::Items, 1);
        if( e.type == DT_DIR ) {
            m_Paths.push_back( EnsureTrailingSlash(e.name), _prefix );
            SourceItem si;
            si.listing_item_index = _listing_item_index;
            si.filename = &m_Paths.back();
            si.type = DeletionType::Permanent;
            m_Script.emplace(si);
            
            ScanDirectory( EnsureTrailingSlash(_path) + e.name, _listing_item_index, si.filename);
        }
        else {
            const auto is_ea_storage = IsEAStorage(vfs, _path, e.name, e.type);
            if( !is_ea_storage ) {
                m_Paths.push_back( e.name, _prefix );
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
        
        const auto path = m_SourceItems[entry.listing_item_index].Directory() +
                          entry.filename->to_str_with_pref();
        const auto &vfs = m_SourceItems[entry.listing_item_index].Host();
        const auto type = entry.type;
        
        if( type == DeletionType::Permanent ) {
            const auto is_dir = IsPathWithTrailingSlash(path);
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

void DeletionJob::DoUnlink( const string &_path, VFSHost &_vfs )
{
    const auto rc = _vfs.Unlink( _path.c_str() );
    if( rc == VFSError::Ok ) {
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
    }
    else {
        const auto resolution = m_OnUnlinkError(rc, _path, _vfs);
        if( resolution == UnlinkErrorResolution::Skip ) {
            Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
        }
        else {
            Stop();
            return;
        }
    }
}

void DeletionJob::DoRmDir( const string &_path, VFSHost &_vfs )
{
    const auto rc = _vfs.RemoveDirectory( _path.c_str() );
    if( rc == VFSError::Ok ) {
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
    }
    else {
        const auto resolution = m_OnRmdirError(rc, _path, _vfs);
        if( resolution == RmdirErrorResolution::Skip ) {
            Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
        }
        else {
            Stop();
            return;
        }
    }
}

void DeletionJob::DoTrash( const string &_path, VFSHost &_vfs, SourceItem _src )
{
    const auto rc = _vfs.Trash( _path.c_str() );
    if( rc == VFSError::Ok ) {
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
    }
    else {
        const auto resolution = m_OnTrashError(rc, _path, _vfs);
        if( resolution == TrashErrorResolution::Skip ) {
            Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
        }
        else if( resolution == TrashErrorResolution::DeletePermanently) {
            SourceItem si = _src;
            si.type = DeletionType::Permanent;
            m_Script.emplace(si);
            const auto is_dir = IsPathWithTrailingSlash(_path);
            if( is_dir )
                ScanDirectory(_path, si.listing_item_index, si.filename);
        }
        else {
            Stop();
            return;
        }
    }
}

int DeletionJob::ItemsInScript() const
{
    return (int)m_Script.size();
}

static bool IsEAStorage(VFSHost &_host, const string &_directory, const char *_filename,
                        uint8_t _unix_type )
{
    if( _unix_type != DT_REG ||
        !_host.IsNativeFS() ||
        _filename[0] != '.' || _filename[1] != '_' || _filename[2] == 0 )
        return false;
    
    char origin_file_path[MAXPATHLEN];
    strcpy(origin_file_path, _directory.c_str());
    if( !IsPathWithTrailingSlash(origin_file_path) )
        strcat( origin_file_path, "/" );
    strcat( origin_file_path, _filename + 2 );
    return _host.Exists( origin_file_path );
}

}
