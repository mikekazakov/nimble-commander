//
//  FileCopyOperationJobFromGeneric.cpp
//  Files
//
//  Created by Michael G. Kazakov on 10.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/attr.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <sys/xattr.h>
#import "FileCopyOperationJobFromGeneric.h"
#import "Common.h"

#define BUFFER_SIZE (512*1024) // 512kb
#define MIN_PREALLOC_SIZE (4096) // will try to preallocate files only if they are larger than 4k

static void AdjustFileTimes(int _target_fd, struct stat *_with_times)
{
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    
    attrs.commonattr = ATTR_CMN_MODTIME;
    fsetattrlist(_target_fd, &attrs, &_with_times->st_mtimespec, sizeof(struct timespec), 0);
    
    attrs.commonattr = ATTR_CMN_CRTIME;
    fsetattrlist(_target_fd, &attrs, &_with_times->st_birthtimespec, sizeof(struct timespec), 0);
    
    attrs.commonattr = ATTR_CMN_ACCTIME;
    fsetattrlist(_target_fd, &attrs, &_with_times->st_atimespec, sizeof(struct timespec), 0);
    
    attrs.commonattr = ATTR_CMN_CHGTIME;
    fsetattrlist(_target_fd, &attrs, &_with_times->st_ctimespec, sizeof(struct timespec), 0);
}

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
    m_Buffer1 = 0;
    m_Buffer2 = 0;
    m_ReadQueue = 0;
    m_WriteQueue = 0;
    m_IOGroup = 0;
}

FileCopyOperationJobFromGeneric::~FileCopyOperationJobFromGeneric()
{
    if(m_Buffer1)
    {
        free(m_Buffer1);
        m_Buffer1 = 0;
    }
    if(m_Buffer2)
    {
        free(m_Buffer2);
        m_Buffer2 = 0;
    }
    if(m_ReadQueue)
    {
        dispatch_release(m_ReadQueue);
        m_ReadQueue = 0;
    }
    if(m_WriteQueue)
    {
        dispatch_release(m_WriteQueue);
        m_WriteQueue = 0;
    }
    if(m_IOGroup)
    {
        dispatch_release(m_IOGroup);
        m_IOGroup = 0;
    }
    
    if(m_ScannedItems)
        FlexChainedStringsChunk::FreeWithDescendants(&m_ScannedItems);
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
    
    m_Stats.SetMaxValue(m_SourceTotalBytes);
    
    m_Buffer1 = malloc(BUFFER_SIZE);
    m_Buffer2 = malloc(BUFFER_SIZE);    
    m_ReadQueue = dispatch_queue_create("info.filesmanager.files.FileCopyOperationJobFromGeneric.read", 0);
    m_WriteQueue = dispatch_queue_create("info.filesmanager.files.FileCopyOperationJobFromGeneric.write", 0);
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
    
    if(m_InitialItems)
        FlexChainedStringsChunk::FreeWithDescendants(&m_InitialItems);
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
                    int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(stat_ret) ForFile:fullpath]
                              WaitForResult];
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
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(stat_ret) ForFile:fullpath]
                      WaitForResult];
        if (result == OperationDialogResult::Retry) goto retry_stat;
        else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
        else if (result == OperationDialogResult::Stop)
        {
            RequestStop();
            return;
        }
    }
}

void FileCopyOperationJobFromGeneric::ProcessItems()
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
    
    struct stat src_stat_buffer;
    if(m_SrcHost->Stat(_src, src_stat_buffer, 0, 0) < 0)
        return false;
    
    // change unix mode
    chmod(_dest, src_stat_buffer.st_mode);
    
    // change flags
    chflags(_dest, src_stat_buffer.st_flags);
    
    return true;
}

void FileCopyOperationJobFromGeneric::EraseXattrs(int _fd_in)
{
    assert(m_Buffer1);
    char *xnames = (char*) m_Buffer1;
    ssize_t xnamesizes = flistxattr(_fd_in, xnames, BUFFER_SIZE, 0);
    if(xnamesizes > 0)
    { // iterate and remove
        char *s = xnames, *e = xnames + xnamesizes;
        while(s < e)
        {
            fremovexattr(_fd_in, s, 0);
            s += strlen(s)+1;
        }
    }
}

void FileCopyOperationJobFromGeneric::CopyXattrs(std::shared_ptr<VFSFile> _file, int _fd_to)
{
    void *buf = m_Buffer1;
    size_t buf_sz = BUFFER_SIZE;
    
    _file->XAttrIterateNames(^bool(const char *name){
        ssize_t res = _file->XAttrGet(name, buf, buf_sz);
        if(res >= 0)
            fsetxattr(_fd_to, name, buf, res, 0, 0);
        return true;
    });    
}

bool FileCopyOperationJobFromGeneric::CopyFileTo(const char *_src, const char *_dest)
{
    int ret, oldumask, destinationfd = -1, dstopenflags=0;
    std::shared_ptr<VFSFile> src_file;
    struct stat src_stat_buffer, dst_stat_buffer;
    bool remember_choice = false, was_successful = false, unlink_on_stop = false, adjust_dst_time = true, erase_xattrs = false;
    unsigned long dest_sz_on_stop = 0, startwriteoff = 0;
    int64_t preallocate_delta = 0;
    __block unsigned long io_leftwrite = 0, io_totalread = 0, io_totalwrote = 0, totaldestsize=0;
    __block bool io_docancel = false;
    char *readbuf = (char*)m_Buffer1, *writebuf = (char*)m_Buffer2;

statsource:
    ret = m_SrcHost->Stat(_src, src_stat_buffer, 0, 0);
    if(ret < 0)
    { // failed to stat source file
        if(m_SkipAll) goto statsource;
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(ret) ForFile:_src] WaitForResult];
        if(result == OperationDialogResult::Retry) goto createsource;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
createsource:
    ret = m_SrcHost->CreateFile(_src, &src_file, 0);
    if(ret < 0)
    { // failed to create source file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(ret) ForFile:_src] WaitForResult];
        if(result == OperationDialogResult::Retry) goto createsource;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
opensource:
    ret = src_file->Open(VFSFile::OF_Read || VFSFile::OF_ShLock);
    if(ret < 0)
    { // failed to open source file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(ret) ForFile:_src] WaitForResult];
        if(result == OperationDialogResult::Retry) goto opensource;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
    totaldestsize = src_stat_buffer.st_size;
    if(stat(_dest, &dst_stat_buffer) != -1) { // file already exist. what should we do now?
        int result;
        if(m_SkipAll) goto cleanup;
        if(m_OverwriteAll) goto decoverwrite;
        if(m_AppendAll) goto decappend;
        
        result = [[m_Operation OnFileExist:_dest
                                   newsize:src_stat_buffer.st_size
                                   newtime:src_stat_buffer.st_mtimespec.tv_sec
                                   exisize:dst_stat_buffer.st_size
                                   exitime:dst_stat_buffer.st_mtimespec.tv_sec
                                  remember:&remember_choice] WaitForResult];
        if(result == FileCopyOperationDR::Overwrite){ if(remember_choice) m_OverwriteAll = true;  goto decoverwrite; }
        if(result == FileCopyOperationDR::Append)   { if(remember_choice) m_AppendAll = true;     goto decappend;    }
        if(result == OperationDialogResult::Skip)     { if(remember_choice) m_SkipAll = true;       goto cleanup;      }
        if(result == OperationDialogResult::Stop)   { RequestStop(); goto cleanup; }
        
        // decisions about what to do with existing destination
    decoverwrite:
        dstopenflags = O_WRONLY;
        erase_xattrs = true;
        unlink_on_stop = true;
        dest_sz_on_stop = 0;
        preallocate_delta = src_stat_buffer.st_size - dst_stat_buffer.st_size;
        goto decend;
    decappend:
        dstopenflags = O_WRONLY;
        totaldestsize += dst_stat_buffer.st_size;
        startwriteoff = dst_stat_buffer.st_size;
        dest_sz_on_stop = dst_stat_buffer.st_size;
        adjust_dst_time = false;
//        copy_xattrs = false;
        unlink_on_stop = false;
        preallocate_delta = src_stat_buffer.st_size;
        goto decend;
    decend:;
    }
    else { // no dest file - just create it
        dstopenflags = O_WRONLY|O_CREAT;
        unlink_on_stop = true;
        dest_sz_on_stop = 0;
        preallocate_delta = src_stat_buffer.st_size;
    }
    
opendest: // open file descriptor for destination
    oldumask = umask(0);
    if(m_Options.copy_unix_flags) // we want to copy src permissions
        destinationfd = open(_dest, dstopenflags, src_stat_buffer.st_mode);
    else // open file with default permissions
        destinationfd = open(_dest, dstopenflags, S_IRUSR | S_IWUSR | S_IRGRP);
    umask(oldumask);
    // TODO: non-blocking opening? current implementation may cause problems

    if(destinationfd == -1)
    {   // failed to open destination file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantOpenDestFile:errno ForFile:_dest] WaitForResult];
        if(result == OperationDialogResult::Retry) goto opendest;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
    // turn off caching for destination file
    fcntl(destinationfd, F_NOCACHE, 1);
    
    // preallocate space for data since we dont want to trash our disk
    if(preallocate_delta > MIN_PREALLOC_SIZE)
    {
        fstore_t preallocstore = {F_ALLOCATECONTIG, F_PEOFPOSMODE, 0, preallocate_delta};
        if(fcntl(destinationfd, F_PREALLOCATE, &preallocstore) == -1)
        {
            preallocstore.fst_flags = F_ALLOCATEALL;
            fcntl(destinationfd, F_PREALLOCATE, &preallocstore);
        }
    }
    
dotruncate: // set right size for destination file
    if(ftruncate(destinationfd, totaldestsize) == -1)
    {   // failed to set dest file size
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyWriteError:ErrnoToNSError() ForFile:_dest] WaitForResult];
        if(result == OperationDialogResult::Retry) goto dotruncate;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
dolseek: // find right position in destination file
    if(startwriteoff > 0 && lseek(destinationfd, startwriteoff, SEEK_SET) == -1)
    {   // failed seek in a file. lolwhat?
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyWriteError:ErrnoToNSError() ForFile:_dest] WaitForResult];
        if(result == OperationDialogResult::Retry) goto dolseek;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
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
                    if(m_SkipAll) {io_docancel = true; return;}
                    int result = [[m_Operation OnCopyReadError:VFSError::ToNSError((int)io_nread) ForFile:_dest] WaitForResult];
                    if(result == OperationDialogResult::Retry) goto doread;
                    if(result == OperationDialogResult::Skip) {io_docancel = true; return;}
                    if(result == OperationDialogResult::SkipAll) {io_docancel = true; m_SkipAll = true; return;}
                    if(result == OperationDialogResult::Stop) { io_docancel = true; RequestStop(); return;}
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
                    int result = [[m_Operation OnCopyWriteError:[NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil] ForFile:_dest] WaitForResult];
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
        m_Stats.SetValue(m_TotalCopied);
    }
    
    // erase destination's xattrs
    if(m_Options.copy_xattrs && erase_xattrs)
        EraseXattrs(destinationfd);

    // copy xattrs from src to dst
    if(m_Options.copy_xattrs && src_file->XAttrCount() > 0)
        CopyXattrs(src_file, destinationfd);
    
    // change ownage
    if(m_Options.copy_unix_owners)
        fchown(destinationfd, src_stat_buffer.st_uid, src_stat_buffer.st_gid);
    
    // change flags
    if(m_Options.copy_unix_flags)
        fchflags(destinationfd, src_stat_buffer.st_flags);
    
    // adjust destination time as source
    if(m_Options.copy_file_times && adjust_dst_time)
        AdjustFileTimes(destinationfd, &src_stat_buffer);
    
    was_successful = true;
    
cleanup:
    src_file->Close();
    if(!was_successful && destinationfd != -1)
    {
        // we need to revert what we've done
        ftruncate(destinationfd, dest_sz_on_stop);
        close(destinationfd);
        destinationfd = -1;
        if(unlink_on_stop)
            unlink(_dest);
    }
    if(destinationfd >= 0) close(destinationfd);
    return was_successful;
}




