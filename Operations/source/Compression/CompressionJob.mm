#include "CompressionJob.h"
#include <Habanero/algo.h>
#include <libarchive/archive.h>
#include <libarchive/archive_entry.h>
#include <Utility/PathManip.h>
#include <VFS/AppleDoubleEA.h>

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
//    int64_t             total_bytes = 0;
    
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
static bool WriteEAsIfAny(VFSFile &_src, struct archive *_a, const char *_source_fn);
static void	archive_entry_copy_stat(struct archive_entry *_ae, const VFSStat &_vfs_stat);

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
    
    m_TargetPathDefined();
    
    //m_Source
    if( auto source = ScanItems()  )
        m_Source = make_unique<Source>( move(*source) );
    else {
        // TODO: process error
    
    }
    
    BuildArchive();
    
    
    if( !IsStopped() )
        SetCompleted();
 //   cout << arcname << endl;
}

bool CompressionJob::BuildArchive()
{
    const auto flags = VFSFlags::OF_Write | VFSFlags::OF_Create |
        VFSFlags::OF_IRUsr | VFSFlags::OF_IWUsr | VFSFlags::OF_IRGrp;
    m_DstVFS->CreateFile(m_TargetArchivePath.c_str(), m_TargetFile, 0);
    if( m_TargetFile->Open(flags) == VFSError::Ok ) {
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
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
        
        if( BlockIfPaused(); IsStopped() )
            return;
    }
}

void CompressionJob::ProcessItem(const chained_strings::node &_node, int _index)
{
    const auto meta = m_Source->metas[_index];
    if ( meta.flags & (int)Source::ItemFlags::is_dir)
        ProcessDirectoryItem(_node, _index);
    else if( meta.flags & (int)Source::ItemFlags::symlink )
        ProcessSymlinkItem(_node, _index);
    else
        ProcessRegularItem(_node, _index);
}

void CompressionJob::ProcessSymlinkItem(const chained_strings::node &_node, int _index)
{
    const auto itemname = _node.to_str_with_pref();
    const auto meta = m_Source->metas[_index];
    const auto source_path = m_Source->base_paths[meta.base_path_indx] + itemname;
    auto &vfs = *m_Source->base_hosts[meta.base_vfs_indx];

    VFSStat stat;
    if( const auto stat_rc = vfs.Stat(source_path.c_str(), stat, VFSFlags::F_NoFollow, 0);
        stat_rc != VFSError::Ok ) {
        const auto res = m_SourceAccessError(stat_rc, source_path, vfs);
        if( res == SourceAccessErrorResolution::Stop )
            Stop();
        return;
    }
    
    char symlink[MAXPATHLEN];
    if( const auto readlink_rc = vfs.ReadSymlink(source_path.c_str(), symlink, MAXPATHLEN, 0);
        readlink_rc != VFSError::Ok ) {
        const auto res = m_SourceAccessError(readlink_rc, source_path, vfs);
        if( res == SourceAccessErrorResolution::Stop )
            Stop();
        return;
    }
    
    auto entry = archive_entry_new();
    auto entry_cleanup = at_scope_end([&]{
        archive_entry_free(entry);
    });
    archive_entry_set_pathname(entry, itemname.c_str());
    archive_entry_copy_stat(entry, stat);
    archive_entry_set_symlink(entry, symlink);
    archive_write_header(m_Archive, entry);
    

//        int vfs_ret = 0;
//        char symlink[MAXPATHLEN];
//        retry_stat_symlink:;
//        while( (vfs_ret = vfs->Stat(sourcepath.c_str(), st, VFSFlags::F_NoFollow, 0)) != 0 ||
//               (vfs_ret = vfs->ReadSymlink(sourcepath.c_str(), symlink, MAXPATHLEN, 0)) != 0 ) {
//            // failed to stat source file
//            if(m_SkipAll) return;
//            int result = m_OnCantAccessSourceItem(vfs_ret,  sourcepath);
//            if(result == OperationDialogResult::Retry) continue;
//            if(result == OperationDialogResult::Skip) return;
//            if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; return;}
//            if(result == OperationDialogResult::Stop) { RequestStop(); return; }
//        }
//        
//        entry = archive_entry_new();
//        archive_entry_set_pathname(entry, itemname);
//        VFSStat::ToSysStat(st, sst);
//        archive_entry_copy_stat(entry, &sst);
//        archive_entry_set_symlink(entry, symlink);
//        archive_write_header(m_Archive, entry);
//        // TODO: error handling??
}

void CompressionJob::ProcessDirectoryItem(const chained_strings::node &_node, int _index)
{
    const auto itemname = _node.to_str_with_pref();
    const auto meta = m_Source->metas[_index];
    const auto source_path = m_Source->base_paths[meta.base_path_indx] + itemname;
    auto &vfs = *m_Source->base_hosts[meta.base_vfs_indx];

    VFSStat vfs_stat;
    if( const auto stat_rc = vfs.Stat(source_path.c_str(), vfs_stat, 0, 0);
        stat_rc != VFSError::Ok ) {
        const auto res = m_SourceAccessError(stat_rc, source_path, vfs);
        if( res == SourceAccessErrorResolution::Stop )
            Stop();
        return;
    }

    auto entry = archive_entry_new();
    auto entry_cleanup = at_scope_end([&]{
        archive_entry_free(entry);
    });
    archive_entry_set_pathname(entry, itemname.c_str());
    archive_entry_copy_stat(entry, vfs_stat);
    archive_write_header(m_Archive, entry);
    // TODO: error handling
    
    VFSFilePtr src_file;
    vfs.CreateFile(source_path.c_str(), src_file, 0);
    if( src_file->Open(VFSFlags::OF_Read) ==  VFSError::Ok ) {
        string name_wo_slash = {begin(itemname), end(itemname)-1};
        WriteEAsIfAny(*src_file, m_Archive, name_wo_slash.c_str());
    }
}

void CompressionJob::ProcessRegularItem(const chained_strings::node &_node, int _index)
{
    const auto itemname = _node.to_str_with_pref();
    const auto meta = m_Source->metas[_index];
    const auto source_path = m_Source->base_paths[meta.base_path_indx] + itemname;
    auto &vfs = *m_Source->base_hosts[meta.base_vfs_indx];

    VFSStat stat;
    if( const auto stat_rc = vfs.Stat(source_path.c_str(), stat, 0, 0);
        stat_rc != VFSError::Ok ) {
        const auto res = m_SourceAccessError(stat_rc, source_path, vfs);
        if( res == SourceAccessErrorResolution::Stop )
            Stop();
        return;
    }

    VFSFilePtr src_file;
    vfs.CreateFile(source_path.c_str(), src_file, 0);
    if( const auto open_rc = src_file->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock);
        open_rc != VFSError::Ok ) {
        const auto res = m_SourceAccessError(open_rc, source_path, vfs);
        if( res == SourceAccessErrorResolution::Stop )
            Stop();
        return;
    }

    const auto entry = archive_entry_new();
    const auto entry_cleanup = at_scope_end([&]{
        archive_entry_free(entry);
    });
    
    archive_entry_set_pathname(entry, itemname.c_str());
    archive_entry_copy_stat(entry, stat);
    archive_write_header(m_Archive, entry);
        
    int buf_sz = 256*1024; // Why 256Kb?
    char buf[buf_sz];
    ssize_t source_read_rc;
    while( (source_read_rc = src_file->Read(buf, buf_sz)) > 0 ) { // reading and compressing itself
        if( BlockIfPaused(); IsStopped() )
            return;
        
        ssize_t la_ret = archive_write_data(m_Archive, buf, source_read_rc);
        assert(la_ret == source_read_rc || la_ret < 0); // currently no cycle here, may need it in future
        // TODO: remove this assert!!!
        
        
        if( la_ret < 0 ) { // some error on write has occured
            // TODO: handle somehow
            Stop();
            return;
            
            // assume that there's I/O problem with target VFS file - say about it
            //                if(m_SkipAll) return;
            //                int result = m_OnCantWriteArchive(m_TargetFile->LastError());
            //                if(result == OperationDialogResult::Retry) goto retry_la_write;
            //                if(result == OperationDialogResult::Skip) return;
            //                if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; return;}
            //                if(result == OperationDialogResult::Stop) { RequestStop(); return; }
        }
            
            // update statistics
        
        Statistics().CommitProcessed(Statistics::SourceType::Bytes, source_read_rc);
//            m_TotalBytesProcessed += vfs_read_ret;
//            m_Stats.SetValue(m_TotalBytesProcessed);
    }
    
    if( source_read_rc < 0 ) {
        m_SourceReadError((int)source_read_rc, source_path, vfs);
        Stop();
        return;
    }
    
    WriteEAsIfAny(*src_file, m_Archive, itemname.c_str());
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
    Statistics().CommitEstimated(Statistics::SourceType::Items, 1);
    if( _item.IsReg() ) {
        Source::ItemMeta meta;
        meta.base_path_indx = _ctx.FindOrInsertBasePath(_item.Directory());
        meta.base_vfs_indx = _ctx.FindOrInsertHost(_item.Host());
        meta.flags = (uint16_t)Source::ItemFlags::no_flags;
        _ctx.metas.emplace_back( meta );
        _ctx.filenames.push_back( _item.Filename(), nullptr );
//        _ctx.total_bytes += _item.Size();
        Statistics().CommitEstimated(Statistics::SourceType::Bytes, _item.Size());
    }
    else if( _item.IsSymlink() ) {
        Source::ItemMeta meta;
        meta.base_path_indx = _ctx.FindOrInsertBasePath(_item.Directory());
        meta.base_vfs_indx = _ctx.FindOrInsertHost(_item.Host());
        meta.flags = (uint16_t)Source::ItemFlags::symlink;
        _ctx.metas.emplace_back( meta );
        _ctx.filenames.push_back( _item.Filename(), nullptr );
    }
    else if( _item.IsDir() ) {
        Source::ItemMeta meta;
        meta.base_path_indx = _ctx.FindOrInsertBasePath(_item.Directory());
        meta.base_vfs_indx = _ctx.FindOrInsertHost(_item.Host());
        meta.flags = (uint16_t)Source::ItemFlags::is_dir;
        _ctx.metas.emplace_back( meta );
        _ctx.filenames.push_back( _item.Filename()+"/", nullptr );
        auto &host = *_item.Host();
        
        vector<string> directory_entries;
        const auto iter_ret = host.IterateDirectoryListing(_item.Path().c_str(),
                                                           [&](const VFSDirEnt &_dirent){
                directory_entries.emplace_back(_dirent.name);
                return true;
            });
        if( iter_ret == VFSError::Ok ) {
            const auto directory_node = &_ctx.filenames.back();
            for( const string &filename: directory_entries )
                if(!ScanItem(_item.Path() + "/" + filename,
                             filename,
                             meta.base_vfs_indx,
                             meta.base_path_indx,
                             directory_node,
                             _ctx))
                    return false;
            // process failure
        }
        else {
            const auto resolution = m_SourceScanError(iter_ret, _item.Path(), host);
            if( resolution == SourceScanErrorResolution::Stop ) {
                Stop();
                return false;
            }
        }
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

    auto &vfs = _ctx.base_hosts[_vfs_no];
    
    int stat_ret = vfs->Stat(_full_path.c_str(), stat_buffer, VFSFlags::F_NoFollow, 0);
    if( stat_ret != VFSError::Ok ) {
        const auto resolution = m_SourceScanError(stat_ret, _full_path, *vfs);
        if( resolution == SourceScanErrorResolution::Stop ) {
            Stop();
            return false;
        }
        return true;
    }

    Statistics().CommitEstimated(Statistics::SourceType::Items, 1);

    if( S_ISREG(stat_buffer.mode) ) {
        Source::ItemMeta meta;
        meta.base_vfs_indx = _vfs_no;
        meta.base_path_indx = _basepath_no;
        meta.flags = (uint16_t)Source::ItemFlags::no_flags;
        _ctx.metas.emplace_back( meta );
        _ctx.filenames.push_back(_filename, _prefix);
//        _ctx.total_bytes += stat_buffer.size;
        Statistics().CommitEstimated(Statistics::SourceType::Bytes, stat_buffer.size);
    }
    else if( S_ISLNK(stat_buffer.mode) ) {
        Source::ItemMeta meta;
        meta.base_vfs_indx = _vfs_no;
        meta.base_path_indx = _basepath_no;
        meta.flags = (uint16_t)Source::ItemFlags::symlink;
        _ctx.metas.emplace_back( meta );
        _ctx.filenames.push_back(_filename, _prefix);
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
        if( iter_ret == VFSError::Ok ) {
            const auto directory_node = &_ctx.filenames.back();
            for( const string &filename: directory_entries )
                if(!ScanItem(_full_path + "/" + filename,
                             filename,
                             meta.base_vfs_indx,
                             meta.base_path_indx,
                             directory_node,
                             _ctx))
                    return false;
        }
        else {
            const auto resolution = m_SourceScanError(iter_ret, _full_path, *vfs);
            if( resolution == SourceScanErrorResolution::Stop ) {
                Stop();
                return false;
            }
        }
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

static void	archive_entry_copy_stat(struct archive_entry *_ae, const VFSStat &_vfs_stat)
{
    struct stat sys_stat;
    VFSStat::ToSysStat(_vfs_stat, sys_stat);
    archive_entry_copy_stat(_ae, &sys_stat);
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

static bool WriteEAs(struct archive *_a, void *_md, size_t _md_s, const char* _path, const char *_name)
{
    char metadata_path[MAXPATHLEN];
    sprintf(metadata_path, "__MACOSX/%s._%s", _path, _name);
    struct archive_entry *entry = archive_entry_new();
    archive_entry_set_pathname(entry, metadata_path);
    archive_entry_set_size(entry, _md_s);
    archive_entry_set_filetype(entry, AE_IFREG);
    archive_entry_set_perm(entry, 0644);
    archive_write_header(_a, entry);
    ssize_t ret = archive_write_data(_a, _md, _md_s); // we may need cycle here
    archive_entry_free(entry);
    
    return ret == _md_s;
}

static bool WriteEAsIfAny(VFSFile &_src, struct archive *_a, const char *_source_fn)
{
    assert(!IsPathWithTrailingSlash(_source_fn));
    
    size_t metadata_sz = 0;
    // will quick almost immediately if there's no EAs
    void *metadata = BuildAppleDoubleFromEA(_src, &metadata_sz);
    if(metadata == 0)
        return true;
    
    char item_path[MAXPATHLEN], item_name[MAXPATHLEN];
    if(GetFilenameFromRelPath(_source_fn, item_name) &&
        GetDirectoryContainingItemFromRelPath(_source_fn, item_path))
    {
        bool ret = WriteEAs(_a, metadata, metadata_sz, item_path, item_name);
        free(metadata);
        return ret;
    }

    free(metadata);
    return true;
}
    
}
