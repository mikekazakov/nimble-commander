#include "CompressionJob.h"
#include <Habanero/algo.h>
#include <libarchive/archive.h>
#include <libarchive/archive_entry.h>


namespace nc::ops
{

// General TODO list for Compression:
// 1. there's no need to call stat() twice per element.
//    it's better to cache results gathered on scanning stage

struct CompressionJob::Source
{
    enum class ItemFlags : uint16_t
    {
        no_flags    = 0 << 0,
        is_dir      = 1 << 0,
        symlink     = 1 << 1
    };
    
    struct ItemMeta
    {
        unsigned    base_path_indx; // m_BasePaths index
        uint16_t    base_vfs_indx;  // m_SourceHosts index
        uint16_t    flags;
    };

    chained_strings     filenames;
    vector<ItemMeta>    metas;
    vector<VFSHostPtr>  base_hosts;
    vector<string>      base_paths;
    int64_t             total_bytes = 0;
    
    uint16_t FindOrInsertHost(const VFSHostPtr &_h)
    {
        return (uint16_t)linear_find_or_insert( base_hosts, _h );
    }

    unsigned FindOrInsertBasePath(const string &_path)
    {
        return (unsigned)linear_find_or_insert( base_paths, _path );
    }
};

static void WriteEmptyArchiveEntry(struct ::archive *_archive);

CompressionJob::CompressionJob(vector<VFSListingItem> _src_files,
                   string _dst_root,
                   VFSHostPtr _dst_vfs):
    m_InitialListingItems{ move(_src_files) },
    m_DstRoot{ move(_dst_root) },
    m_DstVFS{ move(_dst_vfs) }
{
    if( m_DstRoot.empty() || m_DstRoot.back() != '/' )
        m_DstRoot += '/';
}
    
CompressionJob::~CompressionJob()
{
}
    
void CompressionJob::Perform()
{
    string proposed_arcname = m_InitialListingItems.size() == 1 ?
        m_InitialListingItems.front().Filename() :
        "Archive"s;  // Localize!
    
    m_TargetArchivePath = FindSuitableFilename(proposed_arcname);
    
    if( m_TargetArchivePath.empty() ) {
        // handle somehow
    }
    
    m_OnTargetPathDefined();
    
    //m_Source
    if( auto source = ScanItems()  )
        m_Source = make_unique<Source>( move(*source) );
    else {
        // TODO: process error
    
    }
    
    BuildArchive();
    
    

    SetCompleted();
    
    
 //   cout << arcname << endl;
}

bool CompressionJob::BuildArchive()
{
    m_DstVFS->CreateFile(m_TargetArchivePath.c_str(), m_TargetFile, 0);
    if(m_TargetFile->Open(VFSFlags::OF_Write | VFSFlags::OF_Create |
                          VFSFlags::OF_IRUsr | VFSFlags::OF_IWUsr | VFSFlags::OF_IRGrp) == 0) {
        m_Archive = archive_write_new();
        archive_write_set_format_zip(m_Archive);
        archive_write_open(m_Archive, this, 0, WriteCallback, 0);
        archive_write_set_bytes_in_last_block(m_Archive, 1);

        ProcessItems();
        
        if( m_Source->filenames.empty() )
            WriteEmptyArchiveEntry(m_Archive);
        
        archive_write_close(m_Archive);
        archive_write_free(m_Archive);
        
        m_TargetFile->Close();
        
        if( IsStopped() )
            m_DstVFS->Unlink(m_TargetArchivePath.c_str(), 0);
    }

    return true;
}

void CompressionJob::ProcessItems()
{

    int n = 0;
    for( const auto&item: m_Source->filenames ) {
//        m_CurrentlyProcessingItem = &i;
        
        ProcessItem( item, n++ );
        
        if( IsStopped() )
            return;
    }
}

void CompressionJob::ProcessItem(const chained_strings::node &_node, int _index)
{
    const auto meta = m_Source->metas[_index];
    if ( meta.flags & (int)Source::ItemFlags::is_dir) {
        ProcessDirectoryItem(_node, _index);
    }
    else if( meta.flags & (int)Source::ItemFlags::symlink ) {
    }
    else {
        ProcessRegularItem(_node, _index);
    }
}

void CompressionJob::ProcessDirectoryItem(const chained_strings::node &_node, int _index)
{
}

void CompressionJob::ProcessRegularItem(const chained_strings::node &_node, int _index)
{
}

string CompressionJob::FindSuitableFilename(const string& _proposed_arcname) const
{
    char fn[MAXPATHLEN];
    
    sprintf(fn, "%s%s.zip", m_DstRoot.c_str(), _proposed_arcname.c_str());
    VFSStat st;
    if(m_DstVFS->Stat(fn, st, VFSFlags::F_NoFollow, 0) != 0)
        return fn;

    for(int i = 2; i < 100; ++i) {
        sprintf(fn, "%s%s %d.zip", m_DstRoot.c_str(), _proposed_arcname.c_str(), i);
        if(m_DstVFS->Stat(fn, st, VFSFlags::F_NoFollow, 0) != 0)
            return fn;
    }
    return "";
}

void CompressionJob::SetOnTargetPathDefined( function<void()> _callback )
{
    m_OnTargetPathDefined = move(_callback);
}
    
const string &CompressionJob::TargetArchivePath() const
{
    return m_TargetArchivePath;
}
  
optional<CompressionJob::Source> CompressionJob::ScanItems()
{
    Source source;
    for( const auto &item: m_InitialListingItems)
        if( !ScanItem(item, source) )
            return nullopt;

    return move(source);
}

bool CompressionJob::ScanItem(const VFSListingItem &_item,
                              Source &_ctx)
{
    if( _item.IsReg() ) {
        Source::ItemMeta meta;
        meta.base_path_indx = _ctx.FindOrInsertBasePath(_item.Directory());
        meta.base_vfs_indx = _ctx.FindOrInsertHost(_item.Host());
        meta.flags = (uint16_t)Source::ItemFlags::no_flags;
        _ctx.metas.emplace_back( meta );
        _ctx.filenames.push_back( _item.Filename(), nullptr );
        _ctx.total_bytes += _item.Size();
    }
    else if( _item.IsSymlink()  ) {
    
    
    }
    else if( _item.IsDir() ) {
        Source::ItemMeta meta;
        meta.base_path_indx = _ctx.FindOrInsertBasePath(_item.Directory());
        meta.base_vfs_indx = _ctx.FindOrInsertHost(_item.Host());
        meta.flags = (uint16_t)Source::ItemFlags::is_dir;
        _ctx.metas.emplace_back( meta );
        _ctx.filenames.push_back( _item.Filename()+"/", nullptr );
        
        vector<string> directory_entries;
        int iter_ret = _item.Host()->IterateDirectoryListing(_item.Path().c_str(),
                                                             [&](const VFSDirEnt &_dirent){
                directory_entries.emplace_back(_dirent.name);
                return true;
            });
        if( iter_ret != VFSError::Ok ) {
            // process failure
        }
        
        const auto directory_node = &_ctx.filenames.back();
        for( const string &filename: directory_entries )
            ScanItem(_item.Path() + "/" + filename,
                     filename,
                     meta.base_vfs_indx,
                     meta.base_path_indx,
                     directory_node,
                     _ctx);
    }
    return true;
}

bool CompressionJob::ScanItem(const string &_full_path,
                              const string &_filename,
                              unsigned _vfs_no,
                              unsigned _basepath_no,
                              const chained_strings::node *_prefix,
                              Source &_ctx)
{
    VFSStat stat_buffer;

//    SourceItemMeta meta;
//    meta.base_path = _basepath_no;
//    meta.vfs = _vfs_no;
    auto &vfs = _ctx.base_hosts[_vfs_no];
//    auto longpath = m_BasePaths[_basepath_no] + _full_path;
    
//retry_stat:
    int stat_ret = vfs->Stat(_full_path.c_str(), stat_buffer, VFSFlags::F_NoFollow, 0);
    if( stat_ret != VFSError::Ok ) {
        // TODO: handle error
        return false;
    }

    if( S_ISREG(stat_buffer.mode) ) {
        Source::ItemMeta meta;
        meta.base_vfs_indx = _vfs_no;
        meta.base_path_indx = _basepath_no;
        meta.flags = (uint16_t)Source::ItemFlags::no_flags;
        _ctx.metas.emplace_back( meta );
        _ctx.filenames.push_back(_filename, _prefix);
        _ctx.total_bytes += stat_buffer.size;
    }
    else if( S_ISLNK(stat_buffer.mode) ) {
//        meta.flags = (uint8_t)ItemFlags::symlink;
//        m_ScannedItemsMeta.emplace_back( meta );
//        m_ScannedItems.push_back(_short_path, _prefix);
    }
    else if( S_ISDIR(stat_buffer.mode) ) {
    
        Source::ItemMeta meta;
        meta.base_vfs_indx = _vfs_no;
        meta.base_path_indx = _basepath_no;
        meta.flags = (uint16_t)Source::ItemFlags::is_dir;
        _ctx.metas.emplace_back( meta );
        _ctx.filenames.push_back( _filename+"/", _prefix );
    
    
        vector<string> directory_entries;
        int iter_ret = vfs->IterateDirectoryListing(_full_path.c_str(),
                                                    [&](const VFSDirEnt &_dirent){
                directory_entries.emplace_back(_dirent.name);
                return true;
            });
        if( iter_ret != VFSError::Ok ) {
            // TODO: process failure
        }

        const auto directory_node = &_ctx.filenames.back();
        for( const string &filename: directory_entries )
            ScanItem(_full_path + "/" + filename,
                     filename,
                     meta.base_vfs_indx,
                     meta.base_path_indx,
                     directory_node,
                     _ctx);
    }

    return true;
}

ssize_t	CompressionJob::WriteCallback(struct archive *,
                                      void *_client_data,
                                      const void *_buffer,
                                      size_t _length)
{
    const auto me = (CompressionJob*)_client_data;
    ssize_t ret = me->m_TargetFile->Write(_buffer, _length);
    if( ret >= 0 )
        return ret;
    return ARCHIVE_FATAL;
}

static void WriteEmptyArchiveEntry(struct ::archive *_archive)
{
    auto entry = archive_entry_new();
    archive_entry_set_pathname(entry, "");
    struct stat st;
    memset( &st, 0, sizeof(st) );
    st.st_mode = S_IFDIR | S_IRWXU;
    archive_entry_copy_stat(entry, &st);
    archive_write_header(_archive, entry);
    archive_entry_free(entry);
}
    
}
