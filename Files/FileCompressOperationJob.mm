//
//  FileCompressOperationJob.mm
//  Files
//
//  Created by Michael G. Kazakov on 21.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/attr.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <sys/xattr.h>
#import "3rd_party/libarchive/archive.h"
#import "3rd_party/libarchive/archive_entry.h"
#import "FileCompressOperationJob.h"
#import "FileCompressOperation.h"
#import "AppleDoubleEA.h"
#import "Common.h"

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

static bool WriteEAsIfAny(shared_ptr<VFSFile> _src, struct archive *_a, const char *_source_fn)
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

void FileCompressOperationJob::Init(vector<string>&& _src_files,
          const string&_src_root,
          VFSHostPtr _src_vfs,
          const string&_dst_root,
          VFSHostPtr _dst_vfs,
          FileCompressOperation *_operation)
{
    m_InitialItems = move(_src_files);
    m_SrcVFS = _src_vfs;
    m_DstVFS = _dst_vfs;
    m_SrcRoot = _src_root;
    if(m_SrcRoot.empty() || m_SrcRoot.back() != '/') m_SrcRoot += '/';
    m_DstRoot = _dst_root;
    if(m_DstRoot.empty() || m_DstRoot.back() != '/') m_DstRoot += '/';

    m_Operation = _operation;
}

void FileCompressOperationJob::Do()
{
    if(FindSuitableFilename(m_TargetFileName))
    {
        ScanItems();
        m_DoneScanning = true;

        m_Stats.SetMaxValue(m_SourceTotalBytes);
        
        m_DstVFS->CreateFile(m_TargetFileName, m_TargetFile, 0);
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
                m_DstVFS->Unlink(m_TargetFileName, 0);
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

bool FileCompressOperationJob::FindSuitableFilename(char* _full_filename)
{
    char fn[MAXPATHLEN];
    char arc_pref[MAXPATHLEN];
    
    if(m_InitialItems.size() > 1)
        strcpy(arc_pref, "Archive");
    else
        strcpy(arc_pref, m_InitialItems.front().c_str());
    
    sprintf(fn, "%s%s.zip", m_DstRoot.c_str(), arc_pref);
    VFSStat st;
    if(m_DstVFS->Stat(fn, st, VFSFlags::F_NoFollow, 0) != 0)
    {
        strcpy(_full_filename, fn);
        return true;
    }

    for(int i = 2; i < 100; ++i)
    {
        sprintf(fn, "%s%s %d.zip", m_DstRoot.c_str(), arc_pref, i);
        if(m_DstVFS->Stat(fn, st, VFSFlags::F_NoFollow, 0) != 0)
        {
            strcpy(_full_filename, fn);
            return true;
        }
    }
    return false;
}

void FileCompressOperationJob::ScanItems()
{
    // iterate in original filenames
    for(const auto&i: m_InitialItems)
    {
        ScanItem(i.c_str(), i.c_str(), 0);
        
        if(CheckPauseOrStop()) return;
    }
}

void FileCompressOperationJob::ScanItem(const char *_full_path, const char *_short_path, const chained_strings::node *_prefix)
{
    char fullpath[MAXPATHLEN];
    strcpy(fullpath, m_SrcRoot.c_str());
    strcat(fullpath, _full_path);
    
    VFSStat stat_buffer;
    
retry_stat:
    int stat_ret = m_SrcVFS->Stat(fullpath, stat_buffer, VFSFlags::F_NoFollow, 0); // no symlinks support currently
    if(stat_ret == VFSError::Ok) {
        if(S_ISREG(stat_buffer.mode))
        {
            m_ItemFlags.push_back((uint8_t)ItemFlags::no_flags);
            m_ScannedItems.push_back(_short_path, _prefix);
            m_SourceTotalBytes += stat_buffer.size;
        }
        else if(S_ISDIR(stat_buffer.mode))
        {
            char dirpath[MAXPATHLEN];
            sprintf(dirpath, "%s/", _short_path);
            m_ItemFlags.push_back((uint8_t)ItemFlags::is_dir);
            m_ScannedItems.push_back(dirpath, _prefix);
            auto dirnode = &m_ScannedItems.back();
            
        retry_opendir:
            int iter_ret = m_SrcVFS->IterateDirectoryListing(fullpath, [&](const VFSDirEnt &_dirent){
                char dirpathnested[MAXPATHLEN];
                sprintf(dirpathnested, "%s/%s", _full_path, _dirent.name);
                ScanItem(dirpathnested, _dirent.name, dirnode);
                if (CheckPauseOrStop())
                    return false;
                return true;
            });
            if(iter_ret != VFSError::Ok)
            {
                int result = [[m_Operation OnCantAccessSourceDir:VFSError::ToNSError(iter_ret) forPath:fullpath] WaitForResult];
                if (result == OperationDialogResult::Retry) goto retry_opendir;
                else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
                else if (result == OperationDialogResult::Stop)
                {
                    RequestStop();
                    return;
                }
            }
        }
    }
    else if (!m_SkipAll)
    {
        int result = [[m_Operation OnCantAccessSourceItem:VFSError::ToNSError(stat_ret) forPath:fullpath] WaitForResult];
        if (result == OperationDialogResult::Retry) goto retry_stat;
        else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
        else if (result == OperationDialogResult::Stop)
        {
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

void FileCompressOperationJob::ProcessItem(const chained_strings::node *_node, int _number)
{
    VFSStat st;
    struct stat sst;
    char itemname[MAXPATHLEN];
    char sourcepath[MAXPATHLEN];
    struct archive_entry *entry = 0;
    _node->str_with_pref(itemname);
    
    // compose real src name
    strcpy(sourcepath, m_SrcRoot.c_str());
    strcat(sourcepath, itemname);
    
    if(m_ItemFlags[_number] & (int)ItemFlags::is_dir)
    { /* directories */
        assert(IsPathWithTrailingSlash(itemname));
        int stat_ret = 0;
        retry_stat_dir:;
        if((stat_ret = m_SrcVFS->Stat(sourcepath, st, 0, 0)) == 0) {
            entry = archive_entry_new();
            archive_entry_set_pathname(entry, itemname);
            VFSStat::ToSysStat(st, sst);
            archive_entry_copy_stat(entry, &sst);
            archive_write_header(m_Archive, entry);
            archive_entry_free(entry);
            entry = 0;
            
            // metadata
            VFSFilePtr src_file;
            m_SrcVFS->CreateFile(sourcepath, src_file, 0);
            if(src_file->Open(VFSFlags::OF_Read) >= 0) {
                itemname[strlen(itemname)-1] = 0; // our paths extracting routine don't works with paths like /Dir/
                WriteEAsIfAny(src_file, m_Archive, itemname); // metadata, currently no error processing here
            }
        }
        else { // failed to stat source directory
            if(m_SkipAll) goto cleanup;
            int result = [[m_Operation OnCantAccessSourceItem:VFSError::ToNSError(stat_ret) forPath:sourcepath] WaitForResult];
            if(result == OperationDialogResult::Retry) goto retry_stat_dir;
            if(result == OperationDialogResult::Skip) goto cleanup;
            if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
            if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
        }
    }
    else
    { /* regular files */
        int stat_ret = 0, open_file_ret = 0;;
        retry_stat_file:;
        if((stat_ret = m_SrcVFS->Stat(sourcepath, st, 0, 0)) == 0) {
            
            VFSFilePtr src_file;
            m_SrcVFS->CreateFile(sourcepath, src_file, 0);
            retry_open_file:;
            if( (open_file_ret = src_file->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock)) == 0) {
                entry = archive_entry_new();
                archive_entry_set_pathname(entry, itemname);
                VFSStat::ToSysStat(st, sst);
                archive_entry_copy_stat(entry, &sst);
                archive_write_header(m_Archive, entry);
            
                int buf_sz = 256*1024;
                char buf[buf_sz];
                ssize_t vfs_read_ret;
                retry_read_src:;
                while( (vfs_read_ret = src_file->Read(buf, buf_sz)) > 0 ) { // reading and compressing itself
                    if(CheckPauseOrStop()) goto cleanup;
                    
                    retry_la_write:
                    ssize_t la_ret = archive_write_data(m_Archive, buf, vfs_read_ret);
                    assert(la_ret == vfs_read_ret || la_ret < 0); // currently no cycle here, may need it in future
                    
                    if(la_ret < 0) { // some error on write has occured
                        // assume that there's I/O problem with target VFS file - say about it
                        if(m_SkipAll) goto cleanup;
                        int result = [[m_Operation OnWriteError:VFSError::ToNSError(m_TargetFile->LastError())] WaitForResult];
                        if(result == OperationDialogResult::Retry) goto retry_la_write;
                        if(result == OperationDialogResult::Skip) goto cleanup;
                        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
                        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
                    }

                    // update statistics
                    m_Stats.SetValue(m_TotalBytesProcessed);
                    m_TotalBytesProcessed += vfs_read_ret;
                }
                
                if(vfs_read_ret < 0) { // error on reading source file
                    if(m_SkipAll) goto cleanup;
                    int result = [[m_Operation OnReadError:VFSError::ToNSError((int)vfs_read_ret) forPath:sourcepath] WaitForResult];
                    if(result == OperationDialogResult::Retry) goto retry_read_src;
                    if(result == OperationDialogResult::Skip) goto cleanup;
                    if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
                    if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
                }
            
                // all was ok, clean after a bit
                archive_entry_free(entry);
                entry = 0;
            
                WriteEAsIfAny(src_file, m_Archive, itemname); // metadata, currently no error processing here
            }
            else { // failed to open source file
                if(m_SkipAll) goto cleanup;
                int result = [[m_Operation OnCantAccessSourceItem:VFSError::ToNSError(stat_ret) forPath:sourcepath] WaitForResult];
                if(result == OperationDialogResult::Retry) goto retry_open_file;
                if(result == OperationDialogResult::Skip) goto cleanup;
                if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
                if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
            }
        }
        else { // failed to stat source file
            if(m_SkipAll) goto cleanup;
            int result = [[m_Operation OnCantAccessSourceItem:VFSError::ToNSError(stat_ret) forPath:sourcepath] WaitForResult];
            if(result == OperationDialogResult::Retry) goto retry_stat_file;
            if(result == OperationDialogResult::Skip) goto cleanup;
            if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
            if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
        }
    }
    
    cleanup:;
    if(entry)
        archive_entry_free(entry);
}

const char *FileCompressOperationJob::TargetFileName() const
{
    return m_TargetFileName;
}

unsigned FileCompressOperationJob::FilesAmount() const
{
    return (unsigned)m_ItemFlags.size();
}

bool FileCompressOperationJob::IsDoneScanning() const
{
    return m_DoneScanning;
}
