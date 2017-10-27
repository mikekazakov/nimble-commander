// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
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
        Stop();
        return;
    }
    
    m_TargetPathDefined();
    
    if( auto source = ScanItems()  )
        m_Source = make_unique<Source>( move(*source) );
    else
        return;

    BuildArchive();
}

bool CompressionJob::BuildArchive()
{
    const auto flags = VFSFlags::OF_Write | VFSFlags::OF_Create |
        VFSFlags::OF_IRUsr | VFSFlags::OF_IWUsr | VFSFlags::OF_IRGrp;
    m_DstVFS->CreateFile(m_TargetArchivePath.c_str(), m_TargetFile, 0);
    const auto open_rc = m_TargetFile->Open(flags);
    if( open_rc == VFSError::Ok ) {
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
    else {
        m_TargetWriteError(open_rc, m_TargetArchivePath, *m_DstVFS);
        Stop();
        return false;
    }

    return true;
}

void CompressionJob::ProcessItems()
{
    int n = 0;
    for( const auto&item: m_Source->filenames ) {
    
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
    while( true ) {
        const auto rc = vfs.Stat(source_path.c_str(), stat, VFSFlags::F_NoFollow, 0);
        if( rc == VFSError::Ok )
            break;
        switch( m_SourceAccessError(rc, source_path, vfs) ) {
            case SourceAccessErrorResolution::Stop: Stop(); return;
            case SourceAccessErrorResolution::Skip: return;
            case SourceAccessErrorResolution::Retry: continue;
        }
    }
    
    char symlink[MAXPATHLEN];
    while( true ) {
        const auto rc = vfs.ReadSymlink(source_path.c_str(), symlink, MAXPATHLEN, 0);
        if( rc == VFSError::Ok )
            break;
        switch( m_SourceAccessError(rc, source_path, vfs) ) {
            case SourceAccessErrorResolution::Stop: Stop(); return;
            case SourceAccessErrorResolution::Skip: return;
            case SourceAccessErrorResolution::Retry: continue;
        }
    }
    
    const auto entry = archive_entry_new();
    const auto entry_cleanup = at_scope_end([&]{
        archive_entry_free(entry);
    });
    archive_entry_set_pathname(entry, itemname.c_str());
    archive_entry_copy_stat(entry, stat);
    archive_entry_set_symlink(entry, symlink);
    archive_write_header(m_Archive, entry);
}

void CompressionJob::ProcessDirectoryItem(const chained_strings::node &_node, int _index)
{
    const auto itemname = _node.to_str_with_pref();
    const auto meta = m_Source->metas[_index];
    const auto source_path = m_Source->base_paths[meta.base_path_indx] + itemname;
    auto &vfs = *m_Source->base_hosts[meta.base_vfs_indx];

    VFSStat vfs_stat;
    while( true ) {
        const auto rc = vfs.Stat(source_path.c_str(), vfs_stat, 0, 0);
        if( rc == VFSError::Ok )
            break;
        switch( m_SourceAccessError(rc, source_path, vfs) ) {
            case SourceAccessErrorResolution::Stop: Stop(); return;
            case SourceAccessErrorResolution::Skip: return;
            case SourceAccessErrorResolution::Retry: continue;
        }
    }

    auto entry = archive_entry_new();
    auto entry_cleanup = at_scope_end([&]{
        archive_entry_free(entry);
    });
    archive_entry_set_pathname(entry, itemname.c_str());
    archive_entry_copy_stat(entry, vfs_stat);
    const auto head_write_rc = archive_write_header(m_Archive, entry);
    if( head_write_rc < 0 ) {
        m_TargetWriteError(m_TargetFile->LastError(), m_TargetArchivePath, *m_DstVFS);
        Stop();
    }
    
    VFSFilePtr src_file;
    vfs.CreateFile(source_path.c_str(), src_file);
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
    while( true ) {
        const auto rc = vfs.Stat(source_path.c_str(), stat, 0);
        if( rc == VFSError::Ok )
            break;
        switch( m_SourceAccessError(rc, source_path, vfs) ) {
            case SourceAccessErrorResolution::Stop: Stop(); return;
            case SourceAccessErrorResolution::Skip: return;
            case SourceAccessErrorResolution::Retry: continue;
        }
    }
    
    VFSFilePtr src_file;
    vfs.CreateFile(source_path.c_str(), src_file);
    
    while( true ) {
        const auto flags = VFSFlags::OF_Read | VFSFlags::OF_ShLock;
        const auto rc = src_file->Open(flags);
        if( rc == VFSError::Ok )
            break;
        switch( m_SourceAccessError(rc, source_path, vfs) ) {
            case SourceAccessErrorResolution::Stop: Stop(); return;
            case SourceAccessErrorResolution::Skip: return;
            case SourceAccessErrorResolution::Retry: continue;
        }
    }

    const auto entry = archive_entry_new();
    const auto entry_cleanup = at_scope_end([&]{
        archive_entry_free(entry);
    });
    
    archive_entry_set_pathname(entry, itemname.c_str());
    archive_entry_copy_stat(entry, stat);
    const auto head_write_rc = archive_write_header(m_Archive, entry);
    if( head_write_rc < 0 ) {
        m_TargetWriteError(m_TargetFile->LastError(), m_TargetArchivePath, *m_DstVFS);
        Stop();
    }
    
    int buf_sz = 256*1024; // Why 256Kb?
    char buf[buf_sz];
    ssize_t source_read_rc;
    while( (source_read_rc = src_file->Read(buf, buf_sz)) > 0 ) { // reading and compressing itself
        if( BlockIfPaused(); IsStopped() )
            return;
        
        ssize_t to_write = source_read_rc,
                la_rc = 0;
        do {
            la_rc = archive_write_data(m_Archive, buf, to_write);
            if( la_rc >= 0 )
                to_write -= la_rc;
            else
                break;
        } while( to_write > 0 );
        
        if( la_rc < 0 ) {
            m_TargetWriteError(m_TargetFile->LastError(), m_TargetArchivePath, *m_DstVFS);
            Stop();
            return;
        }
        
        Statistics().CommitProcessed(Statistics::SourceType::Bytes, source_read_rc);
    }
    
    if( source_read_rc < 0 )
        switch( m_SourceReadError((int)source_read_rc, source_path, vfs) ) {
            case SourceReadErrorResolution::Stop: Stop(); return;
            case SourceReadErrorResolution::Skip: return;
        }
    
    WriteEAsIfAny(*src_file, m_Archive, itemname.c_str());
}

string CompressionJob::FindSuitableFilename(const string& _proposed_arcname) const
{
    char fn[MAXPATHLEN];
    
    sprintf(fn, "%s%s.zip", m_DstRoot.c_str(), _proposed_arcname.c_str());
    VFSStat st;
    if( m_DstVFS->Stat(fn, st, VFSFlags::F_NoFollow, 0) != 0 )
        return fn;

    for(int i = 2; i < 100; ++i) {
        sprintf(fn, "%s%s %d.zip", m_DstRoot.c_str(), _proposed_arcname.c_str(), i);
        if( m_DstVFS->Stat(fn, st, VFSFlags::F_NoFollow, 0) != 0 )
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
        while( true) {
            const auto callback = [&](const VFSDirEnt &_dirent){
                directory_entries.emplace_back(_dirent.name);
                return true;
            };
            const auto rc = host.IterateDirectoryListing(_item.Path().c_str(), callback);
            if( rc == VFSError::Ok )
                break;
            switch( m_SourceScanError(rc, _item.Path(), host) ) {
                case SourceScanErrorResolution::Stop:   Stop(); return false;
                case SourceScanErrorResolution::Skip:   return true;
                case SourceScanErrorResolution::Retry:  continue;
            }
        }
        
        const auto directory_node = &_ctx.filenames.back();
        for( const string &filename: directory_entries ) {
            const auto scan_ok = ScanItem(_item.Path() + "/" + filename,
                                          filename,
                                          meta.base_vfs_indx,
                                          meta.base_path_indx,
                                          directory_node,
                                          _ctx);
            if( !scan_ok )
                return false;
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
    
    while( true ) {
        const auto rc = vfs->Stat(_full_path.c_str(), stat_buffer, VFSFlags::F_NoFollow, 0);
        if( rc == VFSError::Ok )
            break;
        switch( m_SourceScanError(rc, _full_path, *vfs) ) {
            case SourceScanErrorResolution::Stop: Stop(); return false;
            case SourceScanErrorResolution::Skip: return true;
            case SourceScanErrorResolution::Retry: continue;
        }
    }

    Statistics().CommitEstimated(Statistics::SourceType::Items, 1);

    if( S_ISREG(stat_buffer.mode) ) {
        Source::ItemMeta meta;
        meta.base_vfs_indx = _vfs_no;
        meta.base_path_indx = _basepath_no;
        meta.flags = (uint16_t)Source::ItemFlags::no_flags;
        _ctx.metas.emplace_back( meta );
        _ctx.filenames.push_back(_filename, _prefix);
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
        while( true ) {
            const auto callback = [&](const VFSDirEnt &_dirent){
                directory_entries.emplace_back(_dirent.name);
                return true;
            };
            const auto rc = vfs->IterateDirectoryListing(_full_path.c_str(), callback);
            if( rc == VFSError::Ok )
                break;
            switch( m_SourceScanError(rc, _full_path, *vfs) ) {
                case SourceScanErrorResolution::Stop: Stop(); return false;
                case SourceScanErrorResolution::Skip: return true;
                case SourceScanErrorResolution::Retry: continue;
            }
        }
        
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
    void *metadata = vfs::BuildAppleDoubleFromEA(_src, &metadata_sz);
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
