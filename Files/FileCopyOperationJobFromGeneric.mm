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
#import "RoutedIO.h"

static const int g_MinPreallocSize = 4096; // will try to preallocate files only if they are larger than 4k

static void AdjustFileTimes(int _target_fd, VFSStat *_with_times)
{
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    
    attrs.commonattr = ATTR_CMN_MODTIME;
    fsetattrlist(_target_fd, &attrs, &_with_times->mtime, sizeof(struct timespec), 0);
    
    attrs.commonattr = ATTR_CMN_CRTIME;
    fsetattrlist(_target_fd, &attrs, &_with_times->btime, sizeof(struct timespec), 0);
    
    attrs.commonattr = ATTR_CMN_ACCTIME;
    fsetattrlist(_target_fd, &attrs, &_with_times->atime, sizeof(struct timespec), 0);
    
    attrs.commonattr = ATTR_CMN_CHGTIME;
    fsetattrlist(_target_fd, &attrs, &_with_times->ctime, sizeof(struct timespec), 0);
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
}

FileCopyOperationJobFromGeneric::~FileCopyOperationJobFromGeneric()
{
}

void FileCopyOperationJobFromGeneric::Init(chained_strings _src_files,
          const char *_src_root,               // dir in where files are located
          shared_ptr<VFSHost> _src_host,  // src host to deal with
          const char *_dest,                   // where to copy
          FileCopyOperationOptions _opts,
          FileCopyOperation *_op
          )
{
    assert(_src_host.get());
    m_Operation = _op;
    m_InitialItems.swap(_src_files);
    m_Options = _opts;
    m_SrcHost = _src_host;
    strcpy(m_SrcDir, _src_root);
    if(m_SrcDir[strlen(m_SrcDir) - 1] != '/') strcat(m_SrcDir, "/");
        
    strcpy(m_Destination, _dest);
    if(m_Destination[strlen(m_Destination) - 1] != '/') strcat(m_Destination, "/");
}

void FileCopyOperationJobFromGeneric::Do()
{
    if(!CheckDestinationIsValidDir())
        goto end;
    if(CheckPauseOrStop()) { SetStopped(); return; }
    
    ScanItems();
    if(CheckPauseOrStop()) { SetStopped(); return; }
    
    m_Stats.SetMaxValue(m_SourceTotalBytes);
    
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
    // iterate in original filenames
    for(const auto&i: m_InitialItems)
    {
        ScanItem(i.c_str(), i.c_str(), 0);
        
        if(CheckPauseOrStop()) return;
    }
}

void FileCopyOperationJobFromGeneric::ScanItem(const char *_full_path, const char *_short_path, const chained_strings::node *_prefix)
{
    char fullpath[MAXPATHLEN];
    strcpy(fullpath, m_SrcDir);
    strcat(fullpath, _full_path);
    
    VFSStat stat_buffer;
    
retry_stat:
    int stat_ret = m_SrcHost->Stat(fullpath, stat_buffer, m_Options.preserve_symlinks ? VFSFlags::F_NoFollow : 0, 0);
    
    if(stat_ret == VFSError::Ok)
    {        
        if(S_ISREG(stat_buffer.mode))
        {
            m_ItemFlags.push_back(ItemFlags::no_flags);
            m_ScannedItems.push_back(_short_path, _prefix);
            m_SourceNumberOfFiles++;
            m_SourceTotalBytes += stat_buffer.size;
        }
        else if(S_ISLNK(stat_buffer.mode)) {
            m_ItemFlags.push_back(ItemFlags::is_symlink);
            m_ScannedItems.push_back(_short_path, _prefix);
        }
        else if(S_ISDIR(stat_buffer.mode))
        {
//            m_IsSingleFileCopy = false;
            char dirpath[MAXPATHLEN];
            sprintf(dirpath, "%s/", _short_path);
            m_ItemFlags.push_back(ItemFlags::is_dir);
            m_ScannedItems.push_back(dirpath, _prefix);
            auto dirnode = &m_ScannedItems.back();
            m_SourceNumberOfDirectories++;
            
        retry_opendir:
            int iter_ret = m_SrcHost->IterateDirectoryListing(fullpath, [&](const VFSDirEnt &_dirent){
                char dirpathnested[MAXPATHLEN];
                sprintf(dirpathnested, "%s/%s", _full_path, _dirent.name);
                ScanItem(dirpathnested, _dirent.name, dirnode);
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
    for(const auto&i: m_ScannedItems)
    {
        m_CurrentlyProcessingItem = &i;
        
        ProcessItem(m_CurrentlyProcessingItem, n++);
        
        if(CheckPauseOrStop()) return;
    }
    
    m_Stats.SetCurrentItem(nullptr);
}

void FileCopyOperationJobFromGeneric::ProcessItem(const chained_strings::node *_node, int _number)
{
    char itemname[MAXPATHLEN];
    char sourcepath[MAXPATHLEN], destinationpath[MAXPATHLEN];
    _node->str_with_pref(itemname);

    // compose real src name
    strcpy(sourcepath, m_SrcDir);
    strcat(sourcepath, itemname);

    // compose dest name
    assert(IsPathWithTrailingSlash(m_Destination)); // just a sanity check.
    strcpy(destinationpath, m_Destination);
    strcat(destinationpath, itemname);
    
    if(strcmp(sourcepath, destinationpath) == 0) return; // do not try to copy item into itself
    
    if(m_ItemFlags[_number] & ItemFlags::is_dir) {
        assert(itemname[strlen(itemname)-1] == '/');
        CopyDirectoryTo(sourcepath, destinationpath);
    }
    else if(m_ItemFlags[_number] & ItemFlags::is_symlink)
        CreateSymlinkTo(sourcepath, destinationpath);
    else
        CopyFileTo(sourcepath, destinationpath);
}

bool FileCopyOperationJobFromGeneric::CreateSymlinkTo(const char *_source_symlink, const char* _tagret_symlink)
{
    char linkpath[MAXPATHLEN];
    int result;
    int sz;
    bool was_succesful = false;
doreadlink:
    sz = m_SrcHost->ReadSymlink(_source_symlink, linkpath, MAXPATHLEN, 0);
    if(sz < 0)
    {   // failed to read original symlink
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError((int)sz) ForFile:_source_symlink] WaitForResult];
        if(result == OperationDialogResult::Retry) goto doreadlink;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
dosymlink:
    result = RoutedIO::Default.symlink(linkpath, _tagret_symlink);
    if(result != 0)
    {   // failed to create a symlink
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantOpenDestFile:ErrnoToNSError() ForFile:_tagret_symlink] WaitForResult];
        if(result == OperationDialogResult::Retry) goto dosymlink;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
    was_succesful = true;
    
cleanup:
    
    return was_succesful;
}

bool FileCopyOperationJobFromGeneric::CopyDirectoryTo(const char *_src, const char *_dest)
{
    auto &io = RoutedIO::Default;
    
    // TODO: existance checking, attributes, error handling and other stuff
    io.mkdir(_dest, 0777);
    
    VFSStat src_stat_buffer;
    if(m_SrcHost->Stat(_src, src_stat_buffer, 0, 0) < 0)
        return false;
    
    // change unix mode
    mode_t mode = src_stat_buffer.mode;
    if((mode & (S_IRWXU | S_IRWXG | S_IRWXO)) == 0)
    { // guard against malformed(?) archives
        mode |= S_IRWXU | S_IRGRP | S_IXGRP;
    }
    io.chmod(_dest, mode);
    
    // change flags
    io.chflags(_dest, src_stat_buffer.flags);
    
    // xattr processing
    if(m_Options.copy_xattrs)
    {
        shared_ptr<VFSFile> src_file;
        if(m_SrcHost->CreateFile(_src, src_file, 0) >= 0)
            if(src_file->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock) >= 0)
                if(src_file->XAttrCount() > 0)
                    CopyXattrsFn(src_file, _dest);
    }
    
    return true;
}

void FileCopyOperationJobFromGeneric::EraseXattrs(int _fd_in)
{
    assert(m_Buffer1);
    char *xnames = (char*) m_Buffer1.get();
    ssize_t xnamesizes = flistxattr(_fd_in, xnames, m_BufferSize, 0);
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

void FileCopyOperationJobFromGeneric::CopyXattrsFn(shared_ptr<VFSFile> _file, const char *_fn_to)
{
    void *buf = m_Buffer1.get();
    size_t buf_sz = m_BufferSize;
    
    _file->XAttrIterateNames(^bool(const char *name){
        ssize_t res = _file->XAttrGet(name, buf, buf_sz);
        if(res >= 0)
            setxattr(_fn_to, name, buf, res, 0, 0);
        return true;
    });
}

void FileCopyOperationJobFromGeneric::CopyXattrs(shared_ptr<VFSFile> _file, int _fd_to)
{
    void *buf = m_Buffer1.get();
    size_t buf_sz = m_BufferSize;
    
    _file->XAttrIterateNames(^bool(const char *name){
        ssize_t res = _file->XAttrGet(name, buf, buf_sz);
        if(res >= 0)
            fsetxattr(_fd_to, name, buf, res, 0, 0);
        return true;
    });    
}

bool FileCopyOperationJobFromGeneric::CopyFileTo(const char *_src, const char *_dest)
{
    auto &io = RoutedIO::Default;
    int ret, oldumask, destinationfd = -1, dstopenflags=0;
    shared_ptr<VFSFile> src_file;
    VFSStat src_stat_buffer;
    struct stat dst_stat_buffer;
    bool remember_choice = false, was_successful = false, unlink_on_stop = false, adjust_dst_time = true, erase_xattrs = false;
    unsigned long dest_sz_on_stop = 0, startwriteoff = 0;
    int64_t preallocate_delta = 0;
    unsigned long io_leftwrite = 0, io_totalread = 0, io_totalwrote = 0, totaldestsize=0;
    bool io_docancel = false;
    char *readbuf = (char*)m_Buffer1.get(), *writebuf = (char*)m_Buffer2.get();

statsource:
    ret = m_SrcHost->Stat(_src, src_stat_buffer, 0, 0);
    if(ret < 0)
    { // failed to stat source file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(ret) ForFile:_src] WaitForResult];
        if(result == OperationDialogResult::Retry) goto createsource;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
createsource:
    ret = m_SrcHost->CreateFile(_src, src_file, 0);
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
    ret = src_file->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock | VFSFlags::OF_NoCache);
    if(ret < 0)
    { // failed to open source file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(ret) ForFile:_src] WaitForResult];
        if(result == OperationDialogResult::Retry) goto opensource;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
    totaldestsize = src_stat_buffer.size;
    if(io.stat(_dest, &dst_stat_buffer) != -1) { // file already exist. what should we do now?
        int result;
        if(m_SkipAll) goto cleanup;
        if(m_OverwriteAll) goto decoverwrite;
        if(m_AppendAll) goto decappend;
        
        result = [[m_Operation OnFileExist:_dest
                                   newsize:src_stat_buffer.size
                                   newtime:src_stat_buffer.mtime.tv_sec
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
        preallocate_delta = src_stat_buffer.size - dst_stat_buffer.st_size;
        goto decend;
    decappend:
        dstopenflags = O_WRONLY;
        totaldestsize += dst_stat_buffer.st_size;
        startwriteoff = dst_stat_buffer.st_size;
        dest_sz_on_stop = dst_stat_buffer.st_size;
        adjust_dst_time = false;
//        copy_xattrs = false;
        unlink_on_stop = false;
        preallocate_delta = src_stat_buffer.size;
        goto decend;
    decend:;
    }
    else { // no dest file - just create it
        dstopenflags = O_WRONLY|O_CREAT;
        unlink_on_stop = true;
        dest_sz_on_stop = 0;
        preallocate_delta = src_stat_buffer.size;
    }
    
opendest: // open file descriptor for destination
    oldumask = umask(0);
    if(m_Options.copy_unix_flags) // we want to copy src permissions
        destinationfd = io.open(_dest, dstopenflags, src_stat_buffer.mode);
    else // open file with default permissions
        destinationfd = io.open(_dest, dstopenflags, S_IRUSR | S_IWUSR | S_IRGRP);
    umask(oldumask);
    // TODO: non-blocking opening? current implementation may cause problems

    if(destinationfd == -1)
    {   // failed to open destination file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantOpenDestFile:ErrnoToNSError() ForFile:_dest] WaitForResult];
        if(result == OperationDialogResult::Retry) goto opendest;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
    // turn off caching for destination file
    fcntl(destinationfd, F_NOCACHE, 1);
    
    // preallocate space for data since we dont want to trash our disk
    if(preallocate_delta > g_MinPreallocSize)
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
     
        ssize_t io_nread = 0;
        m_IOGroup.Run([&]{
        doread:
            if(io_totalread < src_file->Size())
            {
                io_nread = src_file->Read(readbuf, m_BufferSize);
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

        m_IOGroup.Run([&]{
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

        m_IOGroup.Wait();
        if(io_docancel) goto cleanup;
        if(io_totalwrote == src_file->Size()) break;
        
        io_leftwrite = io_nread;
        swap(readbuf, writebuf); // swap our work buffers - read buffer become write buffer and vice versa
        
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
    if(m_Options.copy_unix_owners) {
        if(io.isrouted()) // long path
            io.chown(_dest, src_stat_buffer.uid, src_stat_buffer.gid);
        else
            fchown(destinationfd, src_stat_buffer.uid, src_stat_buffer.gid);
    }
    
    // change flags
    if(m_Options.copy_unix_flags) {
        if(io.isrouted()) // long path
            io.chflags(_dest, src_stat_buffer.flags);
        else
            fchflags(destinationfd, src_stat_buffer.flags);
    }
    
    // adjust destination time as source
    if(m_Options.copy_file_times && adjust_dst_time)
        AdjustFileTimes(destinationfd, &src_stat_buffer);
    
    was_successful = true;
    
cleanup:
    if(src_file)
        src_file->Close();
    if(!was_successful && destinationfd != -1)
    {
        // we need to revert what we've done
        ftruncate(destinationfd, dest_sz_on_stop);
        close(destinationfd);
        destinationfd = -1;
        if(unlink_on_stop)
            io.unlink(_dest);
    }
    if(destinationfd >= 0) close(destinationfd);
    return was_successful;
}




