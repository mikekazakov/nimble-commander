//
//  FileCompressOperationJob.mm
//  Files
//
//  Created by Michael G. Kazakov on 21.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <sys/attr.h>
#include <sys/dirent.h>
#include <sys/stat.h>
#include <sys/xattr.h>
#include <Habanero/algo.h>
#include "../../3rd_party/libarchive/archive.h"
#include "../../3rd_party/libarchive/archive_entry.h"
#include "../../AppleDoubleEA.h"
#include "../../Common.h"
#include "FileCompressOperationJob.h"

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

FileCompressOperationJob::FileCompressOperationJob():
    m_SkipAll(0),
    m_SourceTotalBytes(0),
    m_TotalBytesProcessed(0),
    m_DoneScanning(false)
{
    m_TargetFileName[0] = 0;
}

FileCompressOperationJob::~FileCompressOperationJob()
{
}

void FileCompressOperationJob::Init(vector<VFSListingItem> _src_files,
          const string&_dst_root,
          VFSHostPtr _dst_vfs)
{
    m_InitialListingItems = move(_src_files);
    m_DstVFS = _dst_vfs;
    m_DstRoot =  EnsureTrailingSlash( _dst_root );
}

void FileCompressOperationJob::Do()
{
    string proposed_arcname = m_InitialListingItems.size() > 1 ? "Archive"s : m_InitialListingItems.front().Filename();
    
    string arcname = FindSuitableFilename(proposed_arcname);
    if( !arcname.empty() ) {
        m_TargetFileName = arcname;
        
        ScanItems();
        m_DoneScanning = true;

        m_Stats.SetMaxValue(m_SourceTotalBytes);
        
        m_DstVFS->CreateFile(m_TargetFileName.c_str(), m_TargetFile, 0);
        if(m_TargetFile->Open(VFSFlags::OF_Write | VFSFlags::OF_Create |
                              VFSFlags::OF_IRUsr | VFSFlags::OF_IWUsr | VFSFlags::OF_IRGrp) == 0)
        {
            m_Archive = archive_write_new();
            archive_write_set_format_zip(m_Archive);
            archive_write_open(m_Archive, this, 0, la_archive_write_callback, 0);
            archive_write_set_bytes_in_last_block(m_Archive, 1);

            ProcessItems();

            archive_write_close(m_Archive);
            archive_write_free(m_Archive);

            m_TargetFile->Close();
    
            if(CheckPauseOrStop())
                m_DstVFS->Unlink(m_TargetFileName.c_str(), 0);
        }
    }
    
    if(CheckPauseOrStop()) { SetStopped(); return; }    
    SetCompleted();
}

ssize_t	FileCompressOperationJob::la_archive_write_callback(struct archive *, void *_client_data, const void *_buffer, size_t _length)
{
    FileCompressOperationJob *pthis = (FileCompressOperationJob*)_client_data;
    
    ssize_t ret = pthis->m_TargetFile->Write(_buffer, _length);
    if(ret >= 0) return ret;
    return ARCHIVE_FATAL;
}

string FileCompressOperationJob::FindSuitableFilename(const string& _proposed_arcname) const
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

void FileCompressOperationJob::ScanItems()
{
    // iterate in original filenames
    
    for(const auto&i: m_InitialListingItems) {
        ScanItem(i.Name(),
                 i.Name(),
                 FindOrInsertHost(i.Host()),
                 FindOrInsertBasePath(i.Directory()),
                 nullptr
                 );
        
        if(CheckPauseOrStop())
            return;
    }
}

void FileCompressOperationJob::ScanItem(const char *_full_path, const char *_short_path, unsigned _vfs_no, unsigned _basepath_no, const chained_strings::node *_prefix)
{
    VFSStat stat_buffer;

    SourceItemMeta meta;
    meta.base_path = _basepath_no;
    meta.vfs = _vfs_no;
    auto &vfs = m_SourceHosts[_vfs_no];
    auto longpath = m_BasePaths[_basepath_no] + _full_path;
    
retry_stat:
    int stat_ret = vfs->Stat(longpath.c_str(), stat_buffer, VFSFlags::F_NoFollow, 0);
    if(stat_ret == VFSError::Ok) {
        if( S_ISREG(stat_buffer.mode) ) {
            meta.flags = (uint8_t)ItemFlags::no_flags;
            m_ScannedItemsMeta.emplace_back( meta );
            m_ScannedItems.push_back(_short_path, _prefix);
            m_SourceTotalBytes += stat_buffer.size;
        }
        else if( S_ISLNK(stat_buffer.mode) ) {
            meta.flags = (uint8_t)ItemFlags::symlink;
            m_ScannedItemsMeta.emplace_back( meta );
            m_ScannedItems.push_back(_short_path, _prefix);
        }
        else if( S_ISDIR(stat_buffer.mode) ) {
            char dirpath[MAXPATHLEN];
            sprintf(dirpath, "%s/", _short_path);
            meta.flags = (uint8_t)ItemFlags::is_dir;
            m_ScannedItemsMeta.emplace_back( meta );
            m_ScannedItems.push_back(dirpath, _prefix);
            auto dirnode = &m_ScannedItems.back();
            
            retry_opendir:
            int iter_ret = vfs->IterateDirectoryListing(longpath.c_str(), [&](const VFSDirEnt &_dirent){
                char dirpathnested[MAXPATHLEN];
                sprintf(dirpathnested, "%s/%s", _full_path, _dirent.name);
                ScanItem(dirpathnested, _dirent.name, _vfs_no, _basepath_no, dirnode);
                if (CheckPauseOrStop())
                    return false;
                return true;
            });
            if(iter_ret != VFSError::Ok) {
                int result = m_OnCantAccessSourceDirectory(iter_ret, longpath);
                if (result == OperationDialogResult::Retry) goto retry_opendir;
                else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
                else if (result == OperationDialogResult::Stop) {
                    RequestStop();
                    return;
                }
            }
        }
    }
    else if (!m_SkipAll) {
        int result = m_OnCantAccessSourceItem(stat_ret, longpath);
        if (result == OperationDialogResult::Retry) goto retry_stat;
        else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
        else if (result == OperationDialogResult::Stop) {
            RequestStop();
            return;
        }
    }
}

void FileCompressOperationJob::ProcessItems()
{
    m_Stats.StartTimeTracking();
    
    int n = 0;
    for(const auto&i: m_ScannedItems)
    {
        m_CurrentlyProcessingItem = &i;
        
        ProcessItem(m_CurrentlyProcessingItem, n++);
        
        if(CheckPauseOrStop()) return;
    }
    
    m_Stats.SetCurrentItem("");
}

void FileCompressOperationJob::ProcessItem(const chained_strings::node *_node, int _index)
{
    VFSStat st;
    struct stat sst;

    struct archive_entry *entry = nullptr;
    auto entry_cleanup = at_scope_end([&]{ // on any errors make sure to clean up allocated libarchive entries
        archive_entry_free(entry); // nullptr is ok here
    });
    
    char itemname[MAXPATHLEN];
    _node->str_with_pref(itemname);
    auto meta = m_ScannedItemsMeta[_index];
    
    // compose real src name
    auto sourcepath = m_BasePaths[ meta.base_path ] + itemname;
    auto vfs = m_SourceHosts[ meta.vfs ];
    
    if (meta.flags & (int)ItemFlags::is_dir) { /* directories */
        assert(IsPathWithTrailingSlash(itemname));
        int stat_ret = 0;
        while( (stat_ret = vfs->Stat(sourcepath.c_str(), st, 0, 0)) != 0 ) {
            // failed to stat source directory
            if(m_SkipAll) return;
            switch ( m_OnCantAccessSourceItem(stat_ret, sourcepath) ) {
                case OperationDialogResult::Retry:      continue;
                case OperationDialogResult::Skip:       return;
                case OperationDialogResult::SkipAll:    m_SkipAll = true; return;
                case OperationDialogResult::Stop:       RequestStop(); return;
                default:                                return;
            }
        }

        entry = archive_entry_new();
        archive_entry_set_pathname(entry, itemname);
        VFSStat::ToSysStat(st, sst);
        archive_entry_copy_stat(entry, &sst);
        archive_write_header(m_Archive, entry);
        // TODO: error handling??
        
        // metadata
        VFSFilePtr src_file;
        vfs->CreateFile(sourcepath.c_str(), src_file, 0);
        if(src_file->Open(VFSFlags::OF_Read) >= 0) {
            itemname[strlen(itemname)-1] = 0; // our paths extracting routine don't works with paths like /Dir/
            WriteEAsIfAny(*src_file, m_Archive, itemname); // metadata, currently no error processing here
        }
    }
    else if( meta.flags & (int)ItemFlags::symlink ) { // symlinks
        int vfs_ret = 0;
        char symlink[MAXPATHLEN];
        retry_stat_symlink:;
        while( (vfs_ret = vfs->Stat(sourcepath.c_str(), st, VFSFlags::F_NoFollow, 0)) != 0 ||
               (vfs_ret = vfs->ReadSymlink(sourcepath.c_str(), symlink, MAXPATHLEN, 0)) != 0 ) {
            // failed to stat source file
            if(m_SkipAll) return;
            int result = m_OnCantAccessSourceItem(vfs_ret,  sourcepath);
            if(result == OperationDialogResult::Retry) continue;
            if(result == OperationDialogResult::Skip) return;
            if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; return;}
            if(result == OperationDialogResult::Stop) { RequestStop(); return; }
        }
        
        entry = archive_entry_new();
        archive_entry_set_pathname(entry, itemname);
        VFSStat::ToSysStat(st, sst);
        archive_entry_copy_stat(entry, &sst);
        archive_entry_set_symlink(entry, symlink);
        archive_write_header(m_Archive, entry);
        // TODO: error handling??
    }
    else { /* regular files */
        int stat_ret = 0, open_file_ret = 0;
        while( (stat_ret = vfs->Stat(sourcepath.c_str(), st, 0, 0)) != 0 ) {
            // failed to stat source file
            if(m_SkipAll) return;
            int result = m_OnCantAccessSourceItem(stat_ret, sourcepath);
            if(result == OperationDialogResult::Retry) continue;
            if(result == OperationDialogResult::Skip) return;
            if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; return;}
            if(result == OperationDialogResult::Stop) { RequestStop(); return; }
        }
        
        VFSFilePtr src_file;
        vfs->CreateFile(sourcepath.c_str(), src_file, 0);
        while( (open_file_ret = src_file->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock)) != 0) {
            // failed to open source file
            if(m_SkipAll) return;
            int result = m_OnCantAccessSourceItem(stat_ret, sourcepath);
            if(result == OperationDialogResult::Retry) continue;
            if(result == OperationDialogResult::Skip) return;
            if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; return;}
            if(result == OperationDialogResult::Stop) { RequestStop(); return; }
        }
        
        entry = archive_entry_new();
        archive_entry_set_pathname(entry, itemname);
        VFSStat::ToSysStat(st, sst);
        archive_entry_copy_stat(entry, &sst);
        archive_write_header(m_Archive, entry);
        
        int buf_sz = 256*1024;
        char buf[buf_sz];
        ssize_t vfs_read_ret;
    retry_read_src: ;
        while( (vfs_read_ret = src_file->Read(buf, buf_sz)) > 0 ) { // reading and compressing itself
            if(CheckPauseOrStop()) return;
            
        retry_la_write:
            ssize_t la_ret = archive_write_data(m_Archive, buf, vfs_read_ret);
            assert(la_ret == vfs_read_ret || la_ret < 0); // currently no cycle here, may need it in future
            
            if(la_ret < 0) { // some error on write has occured
                // assume that there's I/O problem with target VFS file - say about it
                if(m_SkipAll) return;
                int result = m_OnCantWriteArchive(m_TargetFile->LastError());
                if(result == OperationDialogResult::Retry) goto retry_la_write;
                if(result == OperationDialogResult::Skip) return;
                if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; return;}
                if(result == OperationDialogResult::Stop) { RequestStop(); return; }
            }
            
            // update statistics
            m_TotalBytesProcessed += vfs_read_ret;
            m_Stats.SetValue(m_TotalBytesProcessed);
        }
        
        if(vfs_read_ret < 0) { // error on reading source file
            if(m_SkipAll) return;
            int result = m_OnCantReadSourceItem((int)vfs_read_ret, sourcepath);
            if(result == OperationDialogResult::Retry) goto retry_read_src;
            if(result == OperationDialogResult::Skip) return;
            if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; return;}
            if(result == OperationDialogResult::Stop) { RequestStop(); return; }
        }
        
        // all was ok, clean will be upon exit
        WriteEAsIfAny(*src_file, m_Archive, itemname); // metadata, currently no error processing here
    }
}

string FileCompressOperationJob::TargetFileName() const
{
    return m_TargetFileName; // may race here and cause UB!!
}

unsigned FileCompressOperationJob::FilesAmount() const
{
    return (unsigned) m_ScannedItemsMeta.size();
}

bool FileCompressOperationJob::IsDoneScanning() const
{
    return m_DoneScanning;
}

uint8_t FileCompressOperationJob::FindOrInsertHost(const VFSHostPtr &_h)
{
    return (uint8_t)linear_find_or_insert( m_SourceHosts, _h );
}

unsigned FileCompressOperationJob::FindOrInsertBasePath(const string &_path)
{
    return (unsigned)linear_find_or_insert( m_BasePaths, _path );
}
