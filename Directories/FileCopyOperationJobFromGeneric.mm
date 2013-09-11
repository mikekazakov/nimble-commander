//
//  FileCopyOperationJobFromGeneric.cpp
//  Files
//
//  Created by Michael G. Kazakov on 10.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/dirent.h>
#import <sys/stat.h>
#include "FileCopyOperationJobFromGeneric.h"

#define BUFFER_SIZE (512*1024) // 512kb

FileCopyOperationJobFromGeneric::FileCopyOperationJobFromGeneric()
{
    m_SourceNumberOfFiles = 0;
    m_SourceNumberOfDirectories = 0;
    m_SourceTotalBytes = 0;
    m_TotalCopied = 0;
    m_SkipAll = false;
    m_OverwriteAll = false;
    m_AppendAll = false;
    m_CurrentlyProcessingItem = 0;
}

FileCopyOperationJobFromGeneric::~FileCopyOperationJobFromGeneric()
{
    
    
}

void FileCopyOperationJobFromGeneric::Init(FlexChainedStringsChunk *_src_files, // passing ownage to Job
          const char *_src_root,               // dir in where files are located
          std::shared_ptr<VFSHost> _src_host,  // src host to deal with
          const char *_dest,                   // where to copy
          FileCopyOperationOptions* _opts,
          FileCopyOperation *_op
          )
{
    assert(_src_host.get());
    m_Operation = _op;
    m_InitialItems = _src_files;
    m_Options = *_opts;
    m_SrcHost = _src_host;
    strcpy(m_SrcDir, _src_root);
    if(m_SrcDir[strlen(m_SrcDir) - 1] != '/') strcat(m_SrcDir, "/");
        
    strcpy(m_Destination, _dest);
}

void FileCopyOperationJobFromGeneric::Do()
{
    if(!CheckDestinationIsValidDir())
        goto end;
    if(CheckPauseOrStop()) { SetStopped(); return; }
    
    ScanItems();
    if(CheckPauseOrStop()) { SetStopped(); return; }
    
    m_Buffer1 = malloc(BUFFER_SIZE);
    m_Buffer2 = malloc(BUFFER_SIZE);    
    m_ReadQueue = dispatch_queue_create("file copy read", 0);
    m_WriteQueue = dispatch_queue_create("file copy write", 0);
    m_IOGroup = dispatch_group_create();

    
    ProcessItems();
    if(CheckPauseOrStop()) { SetStopped(); return; }
    
end:
    if(CheckPauseOrStop()) { SetStopped(); return; }
    SetCompleted();
    m_Operation = nil;
}

bool FileCopyOperationJobFromGeneric::CheckDestinationIsValidDir()
{
    return VFSNativeHost::SharedHost()->IsDirectory(m_Destination, 0, 0);
}

void FileCopyOperationJobFromGeneric::ScanItems()
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

void FileCopyOperationJobFromGeneric::ScanItem(const char *_full_path, const char *_short_path, const FlexChainedStringsChunk::node *_prefix)
{
    char fullpath[MAXPATHLEN];
    strcpy(fullpath, m_SrcDir);
    strcat(fullpath, _full_path);
    
    struct stat stat_buffer;
    
retry_stat:
    int stat_ret = m_SrcHost->Stat(fullpath, stat_buffer, 0, 0); // no symlinks support currently
    
    if(stat_ret == VFSError::Ok)
    {        
        if(S_ISREG(stat_buffer.st_mode))
        {
            m_ItemFlags.push_back((uint8_t)ItemFlags::no_flags);
            m_ScannedItemsLast = m_ScannedItemsLast->AddString(_short_path, _prefix);
            m_SourceNumberOfFiles++;
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
            m_SourceNumberOfDirectories++;
            
        retry_opendir:
            int iter_ret = m_SrcHost->IterateDirectoryListing(fullpath, ^bool(struct dirent &_dirent){
                char dirpathnested[MAXPATHLEN];
                sprintf(dirpathnested, "%s/%s", _full_path, _dirent.d_name);
                ScanItem(dirpathnested, _dirent.d_name, dirnode);
                if (CheckPauseOrStop())
                    return false;
                return true;
            });
            if(iter_ret != VFSError::Ok)
            {
                // TODO: error handling
            }
        }
    }
    else if (!m_SkipAll)
    {
        // TODO: error handling
    }
}

void FileCopyOperationJobFromGeneric::ProcessItems()
{
    int n = 0;
    for(const auto&i: *m_ScannedItems)
    {
        m_CurrentlyProcessingItem = &i;
        
        ProcessItem(m_CurrentlyProcessingItem, n++);
        
        if(CheckPauseOrStop()) return;
    }
}

void FileCopyOperationJobFromGeneric::ProcessItem(const FlexChainedStringsChunk::node *_node, int _number)
{
    char itemname[MAXPATHLEN];
    char sourcepath[MAXPATHLEN], destinationpath[MAXPATHLEN];
    _node->str_with_pref(itemname);

    // compose real src name
    strcpy(sourcepath, m_SrcDir);
    strcat(sourcepath, itemname);

    // compose dest name
    assert(m_Destination[strlen(m_Destination)-1] == '/'); // just a sanity check.
    strcpy(destinationpath, m_Destination);
    strcat(destinationpath, itemname);
    
    if(strcmp(sourcepath, destinationpath) == 0) return; // do not try to copy item into itself
    
    if(m_ItemFlags[_number] & (int)ItemFlags::is_dir)
    {
        assert(itemname[strlen(itemname)-1] == '/');
            
        

        CopyDirectoryTo(sourcepath, destinationpath);
    }
    else
    {
        CopyFileTo(sourcepath, destinationpath);
    }
    
    
    
}

bool FileCopyOperationJobFromGeneric::CopyDirectoryTo(const char *_src, const char *_dest)
{
    // TODO: existance checking, attributes, error handling and other stuff
    mkdir(_dest, 0777);
    return true;
}

bool FileCopyOperationJobFromGeneric::CopyFileTo(const char *_src, const char *_dest)
{
    int ret, oldumask, destinationfd = -1;
    std::shared_ptr<VFSFile> src_file;
    __block unsigned long io_leftwrite = 0, io_totalread = 0, io_totalwrote = 0;
    __block bool io_docancel = false;
    char *readbuf = (char*)m_Buffer1, *writebuf = (char*)m_Buffer2;
    
    ret = m_SrcHost->CreateFile(_src, &src_file, 0);
    if(ret < 0)
    {
        // TODO: error handling here
        return false;
    }
    
    ret = src_file->Open(VFSFile::OF_Read || VFSFile::OF_ShLock);
    if(ret < 0)
    {
        // TODO: error handling here
        goto cleanup;
    }
    
    oldumask = umask(0);
    destinationfd = open(_dest, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP); // open file with default permissions
    umask(oldumask);

    if(destinationfd < 0)
    {
        // TODO: error handling here
        goto cleanup;
    }
    
    while(true)
    {
        if(CheckPauseOrStop()) goto cleanup;
     
        __block ssize_t io_nread = 0;
        dispatch_group_async(m_IOGroup, m_ReadQueue, ^{
        doread:
            if(io_totalread < src_file->Size())
            {
                io_nread = src_file->Read(readbuf, BUFFER_SIZE);
                if(io_nread < 0)
                {
                    // TODO: error handling here
                    io_docancel = true;
                    return;
                }
                io_totalread += io_nread;
            }
        });

        dispatch_group_async(m_IOGroup, m_WriteQueue, ^{
            unsigned long alreadywrote = 0;
            while(io_leftwrite > 0)
            {
            dowrite:
                ssize_t nwrite = write(destinationfd, writebuf + alreadywrote, io_leftwrite);
                if(nwrite == -1)
                {
                    if(m_SkipAll) {io_docancel = true; return;}
                    int result = [[m_Operation OnCopyWriteError:errno ForFile:_dest] WaitForResult];
                    if(result == OperationDialogResult::Retry) goto dowrite;
                    if(result == OperationDialogResult::Skip) {io_docancel = true; return;}
                    if(result == OperationDialogResult::SkipAll) {io_docancel = true; m_SkipAll = true; return;}
                    if(result == OperationDialogResult::Stop) { io_docancel = true; RequestStop(); return;}
                }
                alreadywrote += nwrite;
                io_leftwrite -= nwrite;
            }
            io_totalwrote += alreadywrote;
            m_TotalCopied += alreadywrote;
        });

        dispatch_group_wait(m_IOGroup, DISPATCH_TIME_FOREVER);
        if(io_docancel) goto cleanup;
        if(io_totalwrote == src_file->Size()) break;
        
        io_leftwrite = io_nread;
        std::swap(readbuf, writebuf); // swap our work buffers - read buffer become write buffer and vice versa
        
        // update statistics
//        m_Stats.SetValue(m_TotalCopied);
    }
    
    
cleanup:
    if(destinationfd >= 0) close(destinationfd);
    return true;
}




