#include <Habanero/algo.h>
#include "../../NativeFSManager.h"
#include "../../Common.h"
#include "../../RoutedIO.h"
#include "Job.h"

static bool CanBeExternalEA(const char *_short_filename)
{
    return  _short_filename[0] == '.' &&
            _short_filename[1] == '_' &&
            _short_filename[2] != 0;
}

static bool EAHasMainFile(const char *_full_ea_path)
{
    char tmp[MAXPATHLEN];
    strcpy(tmp, _full_ea_path);
    
    char *last_dst = strrchr(tmp, '/');
    const char *last_src = strrchr(_full_ea_path, '/'); // suboptimal
    
    strcpy(last_dst + 1, last_src + 3);
    
    struct stat st;
    return lstat(tmp, &st) == 0;
}

void FileDeletionOperationJobNew::Init(vector<VFSListingItem> _files, FileDeletionOperationType _type)
{
    if( (_type == FileDeletionOperationType::MoveToTrash || _type == FileDeletionOperationType::SecureDelete) &&
       !all_of(begin(_files), end(_files), [](auto &i) { return i.Host()->IsNativeFS(); } ) )
        throw invalid_argument("FileDeletionOperationJobNew::Init invalid work mode for current source items");
    
    m_OriginalItems = move(_files);
}

void FileDeletionOperationJobNew::Do()
{
    DoScan();
    DoProcess();
    
    if( CheckPauseOrStop() ) { SetStopped(); return; }
    SetCompleted();    
}

static bool IsAnExternalExtenedAttributesStorage( VFSHost &_host, const string &_path, const string& _item_name, const VFSStat &_st )
{
    // currently we think that ExtEAs can be only on native VFS
    if( !_host.IsNativeFS() )
        return false;
    
    // any ExtEA should have ._Filename format
    auto cstring = _item_name.c_str();
    if( cstring[0] != '.' || cstring[1] != '_' || cstring[2] == 0 )
        return false;
    
    // check if current filesystem uses external eas
    auto fs_info = NativeFSManager::Instance().VolumeFromDevID( _st.dev );
    if( !fs_info || fs_info->interfaces.extended_attr == true )
        return false;
    
    // check if a 'main' file exists
    char path[MAXPATHLEN];
    strcpy(path, _path.c_str());
    
    // some magick to produce /path/subpath/filename from a /path/subpath/._filename
    char *last_dst = strrchr(path, '/');
    if( !last_dst )
        return false;
    strcpy( last_dst + 1, cstring + 2 );
    
    return _host.Exists( path );
}

void FileDeletionOperationJobNew::DoScan()
{
    SourceItems db;
    vector<int> order;

    for( auto&i: m_OriginalItems ) {
        if(CheckPauseOrStop())
            return;
        
        auto host_indx = db.InsertOrFindHost(i.Host());
        auto &host = db.Host(host_indx);
        auto base_dir_indx = db.InsertOrFindBaseDir(i.Directory());
        function<void(int _parent_ind, const string &_full_relative_path, const string &_item_name)> // need function holder for recursion to work
        scan_item = [this, &db, &order, host_indx, &host, base_dir_indx, &scan_item] (int _parent_ind,
                                                                                      const string &_full_relative_path,
                                                                                      const string &_item_name
                                                                                      ) {
            // compose a full path for current entry
            string path = db.BaseDir(base_dir_indx) + _full_relative_path;
            
            // gather stat() information regarding current entry
            VFSStat st;
            if( host.Stat(path.c_str(), st, VFSFlags::F_NoFollow, nullptr) == 0 ) {
                int current_index = -1;
                if( S_ISREG(st.mode) ) {
                    if( !IsAnExternalExtenedAttributesStorage(host, path, _item_name, st) )
                       current_index = db.InsertItem(host_indx, base_dir_indx, _parent_ind, _item_name, st);
                } else if( S_ISLNK(st.mode) ) {
                    current_index = db.InsertItem(host_indx, base_dir_indx, _parent_ind, _item_name, st);
                }
                else if( S_ISDIR(st.mode) ) {
                    current_index = db.InsertItem(host_indx, base_dir_indx, _parent_ind, _item_name, st);
                    
                    bool should_go_inside = m_Type != FileDeletionOperationType::MoveToTrash;
                    if( should_go_inside ) {
                        vector<string> dir_ents;
                        host.IterateDirectoryListing(path.c_str(), [&](auto &_) { dir_ents.emplace_back(_.name); return true; });
                        
                        for( auto &entry: dir_ents ) {
                            if(CheckPauseOrStop())
                                return;
                            // go into recursion
                            scan_item(current_index,
                                      _full_relative_path + '/' + entry,
                                      entry);
                        }
                    }
                }
                
                if( current_index >= 0)
                    order.emplace_back(current_index);
            }
        };
        scan_item(-1,
                  i.Filename(),
                  i.Filename()
                  );
    }
    
    if(CheckPauseOrStop())
        return;
    
    m_SourceItems = move(db);
    m_DeleteOrder = move(order);
}

void FileDeletionOperationJobNew::DoProcess()
{
//    for( int index = 0, index_end = m_SourceItems.ItemsAmount(); index != index_end; ++index ) {
    for(auto index: m_DeleteOrder) {
        auto source_mode = m_SourceItems.ItemMode(index);
        auto&source_host = m_SourceItems.ItemHost(index);
        auto source_path = m_SourceItems.ComposeFullPath(index);


        
        StepResult step_result = StepResult::Stop;
        if( source_host.IsNativeFS() ) {
            if( m_Type == FileDeletionOperationType::Delete )
                step_result = DoNativeDelete(source_path, source_mode);
            else if( m_Type == FileDeletionOperationType::MoveToTrash )
                step_result = DoNativeTrash(source_path, source_mode);
            else if( m_Type == FileDeletionOperationType::SecureDelete )
                step_result = DoNativeSecureDelete(source_path, source_mode);
        }
        else
            step_result = DoVFSDelete(source_host, source_path, source_mode);
        
        
    }
    
    
}

FileDeletionOperationJobNew::StepResult FileDeletionOperationJobNew::DoNativeDelete(const string& _path, uint16_t _mode)
{
    auto &io = RoutedIO::Default;
    
    if( S_ISDIR(_mode) ) {
        int ret = io.rmdir( _path.c_str() );
        
            // process return code
        
    }
    else {
        int ret = io.unlink( _path.c_str() );
        
            // process return code
        
    }
    

    
    
    return StepResult::Ok;
}

FileDeletionOperationJobNew::StepResult FileDeletionOperationJobNew::DoNativeTrash(const string& _path, uint16_t _mode)
{
    int ret = TrashItem(_path, _mode);

    // process return code
    
    return StepResult::Ok;
}

FileDeletionOperationJobNew::StepResult FileDeletionOperationJobNew::DoNativeSecureDelete(const string& _path, uint16_t _mode)
{
    return StepResult::Ok;
}

FileDeletionOperationJobNew::StepResult FileDeletionOperationJobNew::DoVFSDelete(VFSHost &_host, const string& _path, uint16_t _mode)
{
    if( S_ISDIR(_mode) ) {
        int ret = _host.RemoveDirectory( _path.c_str() );

            // process return code
    }
    else {
        int ret = _host.Unlink( _path.c_str() );
        
            // process return code
    }
    
    
    return StepResult::Ok;
}

int FileDeletionOperationJobNew::SourceItems::InsertItem( uint16_t _host_index, unsigned _base_dir_index, int _parent_index, string _item_name, const VFSStat &_stat )
{
    if( _host_index >= m_SourceItemsHosts.size() ||
       _base_dir_index >= m_SourceItemsBaseDirectories.size() ||
       (_parent_index >= 0 && _parent_index >= m_Items.size() ) )
        throw invalid_argument("FileCopyOperationJobNew::SourceItems::InsertItem: invalid index");
    
    SourceItem it;
    it.item_name = S_ISDIR(_stat.mode) ? EnsureTrailingSlash( move(_item_name) ) : move( _item_name );
    it.parent_index = _parent_index;
    it.base_dir_index = _base_dir_index;
    it.host_index = _host_index;
    it.mode = _stat.mode;
//    it.dev_num = _stat.dev;
//    it.item_size = _stat.size;
    
    m_Items.emplace_back( move(it) );
    
    return int(m_Items.size() - 1);
}

VFSHost &FileDeletionOperationJobNew::SourceItems::Host( uint16_t _host_ind ) const
{
    return *m_SourceItemsHosts.at(_host_ind);
}

uint16_t FileDeletionOperationJobNew::SourceItems::InsertOrFindHost( const VFSHostPtr &_host )
{
    return (uint16_t)linear_find_or_insert(m_SourceItemsHosts, _host);    
}
    
const string &FileDeletionOperationJobNew::SourceItems::BaseDir( unsigned _base_dir_ind ) const
{
    return m_SourceItemsBaseDirectories.at(_base_dir_ind);
}

unsigned FileDeletionOperationJobNew::SourceItems::InsertOrFindBaseDir( const string &_dir )
{
    return (unsigned)linear_find_or_insert(m_SourceItemsBaseDirectories, _dir);
}

const string& FileDeletionOperationJobNew::SourceItems::ItemName( int _item_no ) const
{
    return m_Items.at(_item_no).item_name;
}

VFSHost &FileDeletionOperationJobNew::SourceItems::ItemHost( int _item_no ) const
{
    return *m_SourceItemsHosts[ m_Items.at(_item_no).host_index ];
}

mode_t FileDeletionOperationJobNew::SourceItems::ItemMode( int _item_no ) const
{
    return m_Items.at(_item_no).mode;
}

int FileDeletionOperationJobNew::SourceItems::ItemsAmount() const noexcept
{
    return (int)m_Items.size();
}

string FileDeletionOperationJobNew::SourceItems::ComposeFullPath( int _item_no ) const
{
    auto rel_path = ComposeRelativePath( _item_no );
    rel_path.insert(0, m_SourceItemsBaseDirectories[ m_Items[_item_no].base_dir_index] );
    return rel_path;
}

string FileDeletionOperationJobNew::SourceItems::ComposeRelativePath( int _item_no ) const
{
    auto &meta = m_Items.at(_item_no);
    array<int, 128> parents;
    int parents_num = 0;
    
    int parent = meta.parent_index;
    while( parent >= 0 ) {
        parents[parents_num++] = parent;
        parent = m_Items[parent].parent_index;
    }
    
    string path;
    for( int i = parents_num - 1; i >= 0; i-- )
        path += m_Items[ parents[i] ].item_name;
    
    path += meta.item_name;
    return path;
}