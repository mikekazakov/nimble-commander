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

FileCompressOperationJob::FileCompressOperationJob():
    m_SkipAll(0),
    m_SourceTotalBytes(0),
    m_TotalBytesProcessed(0)
{
}

FileCompressOperationJob::~FileCompressOperationJob()
{
    if(m_InitialItems)
        FlexChainedStringsChunk::FreeWithDescendants(&m_InitialItems);
    if(m_ScannedItems)
        FlexChainedStringsChunk::FreeWithDescendants(&m_ScannedItems);
}

void FileCompressOperationJob::Init(FlexChainedStringsChunk* _src_files,
          const char*_src_root,
          std::shared_ptr<VFSHost> _src_vfs,
          const char* _dst_root,
          std::shared_ptr<VFSHost> _dst_vfs,
          FileCompressOperation *_operation)
{
    m_InitialItems = _src_files;
    m_SrcVFS = _src_vfs;
    m_DstVFS = _dst_vfs;
    strcpy(m_SrcRoot, _src_root);
    if(m_SrcRoot[strlen(m_SrcRoot)-1] != '/') strcat(m_SrcRoot, "/");
    strcpy(m_DstRoot, _dst_root);
    if(m_DstRoot[strlen(m_DstRoot)-1] != '/') strcat(m_DstRoot, "/");
    m_Operation = _operation;
}

void FileCompressOperationJob::Do()
{
    ScanItems();
  
    m_Stats.SetMaxValue(m_SourceTotalBytes);
    
    char target_archive[MAXPATHLEN];
    if(FindSuitableFilename(target_archive))
    {
        m_DstVFS->CreateFile(target_archive, &m_TargetFile, 0);
        m_TargetFile->Open(VFSFile::OF_Write | VFSFile::OF_Create);
    
        m_Archive = archive_write_new();
        archive_write_set_format_zip(m_Archive);
        archive_write_open(m_Archive, this, 0, la_archive_write_callback, 0);
        archive_write_set_bytes_in_last_block(m_Archive, 1);

        ProcessItems();

        archive_write_close(m_Archive);
        archive_write_free(m_Archive);

        m_TargetFile->Close();
    
    }
    
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
    
    if(m_InitialItems->Amount() > 1)
        strcpy(arc_pref, "Archive");
    else
        strcpy(arc_pref, (*m_InitialItems)[0].str());
    
    sprintf(fn, "%s%s.zip", m_DstRoot, arc_pref);
    struct stat st;
    if(m_DstVFS->Stat(fn, st, VFSHost::F_NoFollow, 0) != 0)
    {
        strcpy(_full_filename, fn);
        return true;
    }

    for(int i = 2; i < 100; ++i)
    {
        sprintf(fn, "%s%s %d.zip", m_DstRoot, arc_pref, i);
        if(m_DstVFS->Stat(fn, st, VFSHost::F_NoFollow, 0) != 0)
        {
            strcpy(_full_filename, fn);
            return true;
        }
    }
    return false;
}

void FileCompressOperationJob::ScanItems()
{
    m_ScannedItems = FlexChainedStringsChunk::Allocate();
    m_ScannedItemsLast = m_ScannedItems;
    // iterate in original filenames
    for(const auto&i: *m_InitialItems)
    {
        ScanItem(i.str(), i.str(), 0);
        
        if(CheckPauseOrStop()) return;
    }
}

void FileCompressOperationJob::ScanItem(const char *_full_path, const char *_short_path, const FlexChainedStringsChunk::node *_prefix)
{
//    NSLog(@"%s", _full_path);
    
    char fullpath[MAXPATHLEN];
    strcpy(fullpath, m_SrcRoot);
    strcat(fullpath, _full_path);
    
    struct stat stat_buffer;
    
retry_stat:
    int stat_ret = m_SrcVFS->Stat(fullpath, stat_buffer, VFSHost::F_NoFollow, 0); // no symlinks support currently
    
    if(stat_ret == VFSError::Ok)
    {
        if(S_ISREG(stat_buffer.st_mode))
        {
            m_ItemFlags.push_back((uint8_t)ItemFlags::no_flags);
            m_ScannedItemsLast = m_ScannedItemsLast->AddString(_short_path, _prefix);
//            m_SourceNumberOfFiles++;
            m_SourceTotalBytes += stat_buffer.st_size;
        }
        else if(S_ISDIR(stat_buffer.st_mode))
        {
            //            m_IsSingleFileCopy = false;
            char dirpath[MAXPATHLEN];
            sprintf(dirpath, "%s/", _short_path);
            m_ItemFlags.push_back((uint8_t)ItemFlags::is_dir);
            m_ScannedItemsLast = m_ScannedItemsLast->AddString(dirpath, _prefix);
            const FlexChainedStringsChunk::node *dirnode = &((*m_ScannedItemsLast)[m_ScannedItemsLast->Amount()-1]);
//            m_SourceNumberOfDirectories++;
            
        retry_opendir:
            int iter_ret = m_SrcVFS->IterateDirectoryListing(fullpath, ^bool(struct dirent &_dirent){
                char dirpathnested[MAXPATHLEN];
                sprintf(dirpathnested, "%s/%s", _full_path, _dirent.d_name);
                ScanItem(dirpathnested, _dirent.d_name, dirnode);
                if (CheckPauseOrStop())
                    return false;
                return true;
            });
            if(iter_ret != VFSError::Ok)
            {
                abort();
/*                int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(stat_ret) ForFile:fullpath]
                              WaitForResult];
                if (result == OperationDialogResult::Retry) goto retry_opendir;
                else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
                else if (result == OperationDialogResult::Stop)
                {
                    RequestStop();
                    return;
                }*/
            }
        }
    }
    else if (!m_SkipAll)
    {
        abort();
/*        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(stat_ret) ForFile:fullpath]
                      WaitForResult];
        if (result == OperationDialogResult::Retry) goto retry_stat;
        else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
        else if (result == OperationDialogResult::Stop)
        {
            RequestStop();
            return;
        }*/
    }
}

void FileCompressOperationJob::ProcessItems()
{
    m_Stats.StartTimeTracking();
    
    int n = 0;
    for(const auto&i: *m_ScannedItems)
    {
        m_CurrentlyProcessingItem = &i;
        
        ProcessItem(m_CurrentlyProcessingItem, n++);
        
        if(CheckPauseOrStop()) return;
    }
    
    m_Stats.SetCurrentItem(nullptr);    
}

void FileCompressOperationJob::ProcessItem(const FlexChainedStringsChunk::node *_node, int _number)
{
    char itemname[MAXPATHLEN];
    char sourcepath[MAXPATHLEN];
    _node->str_with_pref(itemname);
    
    // compose real src name
    strcpy(sourcepath, m_SrcRoot);
    strcat(sourcepath, itemname);
    
    if(m_ItemFlags[_number] & (int)ItemFlags::is_dir)
    {
        assert(itemname[strlen(itemname)-1] == '/');
        struct stat st;
        if(m_SrcVFS->Stat(sourcepath, st, 0, 0) == 0)
        {
            struct archive_entry *entry = archive_entry_new();
            archive_entry_set_pathname(entry, itemname);
            archive_entry_copy_stat(entry, &st);
            archive_write_header(m_Archive, entry);
            archive_entry_free(entry);
            
            // metadata
            std::shared_ptr<VFSFile> src_file;
            m_SrcVFS->CreateFile(sourcepath, &src_file, 0);
            if(src_file->Open(VFSFile::OF_Read) >= 0)
            {
                // metadata
                size_t metadata_sz = 0;
                // will quick almost immediately if there's no EAs
                void *metadata = BuildAppleDoubleFromEA(src_file, &metadata_sz);
                if(metadata != 0) {
                    itemname[strlen(itemname)-1] = 0; // our paths extracting routine don't works with paths like /Dir/
                    char item_path[MAXPATHLEN], item_name[MAXPATHLEN];
                    if(GetFilenameFromRelPath(itemname, item_name) && GetDirectoryContainingItemFromRelPath(itemname, item_path))
                    {
                        char metadata_path[MAXPATHLEN];
                        sprintf(metadata_path, "__MACOSX/%s._%s", item_path, item_name);
                        struct archive_entry *entry = archive_entry_new();
                        archive_entry_set_pathname(entry, metadata_path);
                        archive_entry_set_size(entry, metadata_sz);
                        archive_entry_set_filetype(entry, AE_IFREG);
                        archive_entry_set_perm(entry, 0644);
                        archive_write_header(m_Archive, entry);
                        archive_write_data(m_Archive, metadata, metadata_sz);
                        archive_entry_free(entry);
                        free(metadata);
                    }
                }
            }
        }
    }
    else
    {
        struct stat st;
        if(m_SrcVFS->Stat(sourcepath, st, 0, 0) == 0)
        {
            std::shared_ptr<VFSFile> src_file;
            m_SrcVFS->CreateFile(sourcepath, &src_file, 0);
            src_file->Open(VFSFile::OF_Read);
            
            struct archive_entry *entry = archive_entry_new();
            archive_entry_set_pathname(entry, itemname);
            archive_entry_copy_stat(entry, &st);
            archive_write_header(m_Archive, entry);
            
            int buf_sz = 256*1024;
            char buf[buf_sz];
            ssize_t vfs_ret;
            while( (vfs_ret = src_file->Read(buf, buf_sz)) > 0 )
            {
                ssize_t ls_ret = archive_write_data(m_Archive, buf, vfs_ret);
                assert(ls_ret == vfs_ret);
                
                // update statistics
                m_Stats.SetValue(m_TotalBytesProcessed);
                m_TotalBytesProcessed += vfs_ret;
            }
            archive_entry_free(entry);
            
            
            // metadata
            size_t metadata_sz = 0;
            // will quick almost immediately if there's no EAs
            void *metadata = BuildAppleDoubleFromEA(src_file, &metadata_sz);
            if(metadata != 0) {
                char item_path[MAXPATHLEN], item_name[MAXPATHLEN];
                if(GetFilenameFromRelPath(itemname, item_name) && GetDirectoryContainingItemFromRelPath(itemname, item_path))
                {
                    char metadata_path[MAXPATHLEN];
                    sprintf(metadata_path, "__MACOSX/%s._%s", item_path, item_name);
                    //                    sprintf(metadata_path, "__MACOSX/%s!!%s", item_path, item_name);
                    struct archive_entry *entry = archive_entry_new();
                    archive_entry_set_pathname(entry, metadata_path);
                    archive_entry_set_size(entry, metadata_sz);
                    archive_entry_set_filetype(entry, AE_IFREG);
                    archive_entry_set_perm(entry, 0644);
                    archive_write_header(m_Archive, entry);
                    archive_write_data(m_Archive, metadata, metadata_sz);
                    archive_entry_free(entry);
                    free(metadata);
                }
            }
        }
    }
    
//    printf("%d,\n", files_written);
}
