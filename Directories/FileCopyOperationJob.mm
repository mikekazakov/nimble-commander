//
//  FileCopyOperationJob.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 09.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "FileCopyOperationJob.h"
#include <algorithm>
#include <sys/types.h>
#include <sys/dirent.h>
#include <sys/stat.h>
#include <dirent.h>
#include <sys/time.h>
#include <sys/xattr.h>
#include <sys/attr.h>
#include <sys/vnode.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <unistd.h>
#include <stdlib.h>

#define BUFFER_SIZE (512*1024) // 512kb
#define MIN_PREALLOC_SIZE (4096) // will try to preallocate files only if they are larger than 4k


FileCopyOperationJob::FileCopyOperationJob():
    m_Operation(0),
    m_InitialItems(0),
    m_SourceNumberOfFiles(0),
    m_SourceNumberOfDirectories(0),
    m_SourceTotalBytes(0),
    m_CurrentlyProcessingItem(0),
    m_Buffer1(0),
    m_Buffer2(0),
    m_SkipAll(false),
    m_OverwriteAll(false),
    m_AppendAll(false),
    m_TotalCopied(0),
    m_IsSingleFileCopy(true)
{
    // in xattr operations we'll use our big Buf1 and Buf2 - they should be quite enough
    // in OS X 10.4-10.6 maximum size of xattr value was 4Kb
    // in OS X 10.7(or in 10.8?) it was increased to 128Kb
    assert( BUFFER_SIZE >= 128 * 1024 ); // should be enough to hold any xattr value
}

FileCopyOperationJob::~FileCopyOperationJob()
{
    if(m_Buffer1) { free(m_Buffer1); m_Buffer1 = 0; }
    if(m_Buffer2) { free(m_Buffer2); m_Buffer2 = 0; }
    m_ReadQueue = 0;
    m_WriteQueue = 0;
    m_IOGroup = 0;
    if(m_ScannedItems)
    {
        FlexChainedStringsChunk::FreeWithDescendants(&m_ScannedItems);
        m_ScannedItems = 0;
    }    
}

void FileCopyOperationJob::Init(FlexChainedStringsChunk *_files, // passing ownage to Job
                         const char *_root,               // dir in where files are located
                         const char *_dest,                // where to copy
                        FileCopyOperation *_op
                         )
{
    m_Operation = _op;
    m_InitialItems = _files;
    strcpy(m_Destination, _dest);
    strcpy(m_SourceDirectory, _root);
}


void FileCopyOperationJob::Do()
{
    ScanDestination();
    if(GetState() == StateStopped) return;
    if(CheckPauseOrStop()) { SetStopped(); return; }

    ScanItems();
    if(GetState() == StateStopped) return;
    if(CheckPauseOrStop()) { SetStopped(); return; }

    // we don't need any more - so free memory as soon as possible
    FlexChainedStringsChunk::FreeWithDescendants(&m_InitialItems);

    m_Buffer1 = malloc(BUFFER_SIZE);
    m_Buffer2 = malloc(BUFFER_SIZE);
    m_ReadQueue = dispatch_queue_create(0, 0);
    m_WriteQueue = dispatch_queue_create(0, 0);
    m_IOGroup = dispatch_group_create();

    ProcessItems();
    if(GetState() == StateStopped) return;
    if(CheckPauseOrStop()) { SetStopped(); return; }
    
    SetCompleted();
    m_Operation = nil;
}

bool FileCopyOperationJob::IsSingleFileCopy() const
{
    return m_IsSingleFileCopy;    
}

void FileCopyOperationJob::ScanDestination()
{
    struct stat stat_buffer;
    if(stat(m_Destination, &stat_buffer) == 0)
    {
        bool isfile = (stat_buffer.st_mode&S_IFMT) == S_IFREG;
        bool isdir  = (stat_buffer.st_mode&S_IFMT) == S_IFDIR;
        
        if(isfile)
            m_CopyMode = CopyToFile;
        else if(isdir)
        {
            m_CopyMode = CopyToFolder;
            if(m_Destination[strlen(m_Destination)-1] != '/')
                strcat(m_Destination, "/"); // add slash at the end
        }
        else
            assert(0); //TODO: implement handling of this weird cases
    }
    else
    { // ok, it's not a valid entry, now we have to analyze what user wants from us
        if(strchr(m_Destination, '/') == 0)
        {   // there's no directories mentions in destination path, let's treat destination as an regular absent file
            // let's think that this destination file should be located in source directory
            char destpath[MAXPATHLEN];
            strcpy(destpath, m_SourceDirectory);
            strcat(destpath, m_Destination);
            strcpy(m_Destination, destpath);
            
            m_CopyMode = CopyToFile;
        }
        else
        {
            // TODO: implement me later: ask user about folder/files choice if need
            // he may want to copy file to /users/abra/newdir/FILE.TXT, which is a file in his mind
            
            // just for now - let's think that it's a directory anyway
            m_CopyMode = CopyToFolder;
            
            if(m_Destination[0] != '/')
            {
                // relative to source directory
                char destpath[MAXPATHLEN];
                strcpy(destpath, m_SourceDirectory);
                strcat(destpath, m_Destination);
                if( destpath[strlen(destpath)-1] != '/' )
                    strcat(destpath, "/");
                strcpy(m_Destination, destpath);
            }
            else
            {
                // absolute path
                if( m_Destination[strlen(m_Destination)-1] != '/' )
                    strcat(m_Destination, "/");
            }
            
            // now we need to check every directory here and create them they are not exist
            
            // TODO: not very efficient implementation, it does many redundant stat calls
            // this algorithm iterates from left to right, but it's better to iterate right-left and then left-right
            // but this work is doing only once per MassCopyOp, so user may not even notice this issue
            
            char destpath[MAXPATHLEN];
            strcpy(destpath, m_Destination);
            char* leftmost = strchr(destpath+1, '/');
            do
            {
                *leftmost = 0;
                if(stat(destpath, &stat_buffer) == -1)
                {
                    // absent part - need to create it
domkdir:            if(mkdir(destpath, 0777) == -1)
                    {
                        int result = [[m_Operation OnDestCantCreateDir:errno ForDir:destpath] WaitForResult];
                        if (result == FileCopyOperationDR::Retry)
                            goto domkdir;
                        if (result == OperationDialogResult::Stop)
                        {
                            SetStopped();
                            return;
                        }
                    }
                }
                *leftmost = '/';

                leftmost = strchr(leftmost+1, '/');
            } while(leftmost != 0);
        }
    }
}

void FileCopyOperationJob::ScanItems()
{
    m_ScannedItems = FlexChainedStringsChunk::Allocate();
    m_ScannedItemsLast = m_ScannedItems;

    if(m_InitialItems->amount > 1)
        m_IsSingleFileCopy = false;
    
    // iterate in original filenames
    for(const auto&i: *m_InitialItems)
    {
        ScanItem(i.str(), i.str(), 0);

        if(GetState() == StateStopped) return;
        if(CheckPauseOrStop()) { SetStopped(); return; }
    }
}

void FileCopyOperationJob::ScanItem(const char *_full_path, const char *_short_path, const FlexChainedStringsChunk::node *_prefix)
{
    // TODO: optimize it ALL!
    // TODO: this path composing can be optimized
    // DANGER: this big buffer can cause stack overflow since ScanItem function is used recursively. FIXME!!!
    // 512Kb for threads in OSX. CHECK ME!
    char fullpath[MAXPATHLEN];
    strcpy(fullpath, m_SourceDirectory);
    strcat(fullpath, _full_path);

    struct stat stat_buffer;
    if(stat(fullpath, &stat_buffer) == 0)
    {
        bool isfile = (stat_buffer.st_mode&S_IFMT) == S_IFREG;
        bool isdir  = (stat_buffer.st_mode&S_IFMT) == S_IFDIR;

        if(isfile)
        {
            m_ScannedItemsLast = m_ScannedItemsLast->AddString(
                                                               _short_path,
                                                               _prefix
                                                               ); // TODO: make this insertion with strlen since we already know it
            m_SourceNumberOfFiles++;
            m_SourceTotalBytes += stat_buffer.st_size;
        }
        else if(isdir)
        {
            m_IsSingleFileCopy = false;
            char dirpath[MAXPATHLEN];
            sprintf(dirpath, "%s/", _short_path);
            m_ScannedItemsLast = m_ScannedItemsLast->AddString(
                                                               dirpath,
                                                               _prefix
                                                               ); // TODO: make this insertion with strlen since we already know it
            const FlexChainedStringsChunk::node *dirnode = &m_ScannedItemsLast->strings[m_ScannedItemsLast->amount-1];
            m_SourceNumberOfDirectories++;
            
            DIR *dirp = opendir(fullpath);
            if( dirp != 0)
            {
                dirent *entp;
                while((entp = readdir(dirp)) != NULL)
                {
                    if(strcmp(entp->d_name, ".") == 0 ||
                       strcmp(entp->d_name, "..") == 0) continue; // TODO: optimize me
                    
                    sprintf(dirpath, "%s/%s", _full_path, entp->d_name);
                    
                    ScanItem(dirpath, entp->d_name, dirnode);
                    
                    // TODO: check if we need to stop;
                }
                
                closedir(dirp);
            }
            else
            {
                //TODO: error handling
            }
        }
    }
    else
    {
        // TODO: error handling?
    }
}

void FileCopyOperationJob::ProcessItems()
{
    for(const auto&i: *m_ScannedItems)
    {
        m_CurrentlyProcessingItem = &i;
        
        ProcessItem(m_CurrentlyProcessingItem);

        if(GetState() == StateStopped) return;
        if(CheckPauseOrStop()) { SetStopped(); return; }
    }
}

void FileCopyOperationJob::ProcessItem(const FlexChainedStringsChunk::node *_node)
{
    assert(_node->len != 0);
    bool src_isdir = _node->str()[_node->len-1] == '/'; // found if item is a directory
    
    if(src_isdir && m_CopyMode == CopyToFile)
        return; // check if item is a directory and we're copying to a file - then just skip it, it's meaningless
    
    // compose file name - reverse lookup
    char itemname[MAXPATHLEN];
    _node->str_with_pref(itemname);
    
    if(src_isdir)
        ProcessDirectory(itemname);
    else
        ProcessFile(itemname);
}

void FileCopyOperationJob::ProcessDirectory(const char *_path)
{
    // TODO: directory attributes, time, permissions and xattrs
    assert(m_Destination[strlen(m_Destination)-1] == '/');
    assert(_path[strlen(_path)-1] == '/');
    
    const int maxdepth = FlexChainedStringsChunk::maxdepth; // 128 directories depth max
    struct stat stat_buffer;
    short slashpos[maxdepth];
    short absentpos[maxdepth];
    int ndirs = 0, nabsent = 0, pathlen = (int)strlen(_path);
    
    char fullpath[MAXPATHLEN];
    char destlen = strlen(m_Destination);
    strcpy(fullpath, m_Destination);
    strcat(fullpath, _path);
    
    for(int i = pathlen-1; i > 0; --i )
        if(_path[i] == '/')
        {
            slashpos[ndirs++] = i + destlen;
            assert(ndirs < maxdepth);
        }
    
    // find absent directories in full path
    for(int i = 0; i < ndirs; ++i)
    {
        fullpath[ slashpos[i] ] = 0;
        int ret = stat(fullpath, &stat_buffer);
        fullpath[ slashpos[i] ] = '/';
        if( ret == -1)
        {
            // TODO: error handling. this can be permission stuff, not absence (?)
            absentpos[nabsent++] = i;
        }
        else
        {
            break; // no need to look up any more
        }
    }
    
    // mkdir absent directories
    for(int i = nabsent-1; i >= 0; --i)
    {
        fullpath[ slashpos[ absentpos[i] ] ] = 0;
domkdir:if(mkdir(fullpath, 0777))
        {
            if(m_SkipAll) return;
            int result = [[m_Operation OnCopyCantCreateDir:errno ForDir:fullpath] WaitForResult];
            if(result == FileCopyOperationDR::Retry)
                goto domkdir;
            if(result == FileCopyOperationDR::Skip) return;
            if(result == FileCopyOperationDR::SkipAll) {m_SkipAll = true; return;}
            if(result == OperationDialogResult::Stop)
            {
                SetStopped();
                return;
            }
        }
        fullpath[ slashpos[ absentpos[i] ] ] = '/';
    }
}

void FileCopyOperationJob::ProcessFile(const char *_path)
{
    // TODO: need to ask about destination volume info to exclude meaningless operations for attrs which are not supported    
    
    struct stat src_stat_buffer, dst_stat_buffer;
    char sourcepath[__DARWIN_MAXPATHLEN], destinationpath[__DARWIN_MAXPATHLEN],
    *sourcepathp=&sourcepath[0], *destinationpathp=&destinationpath[0],
    *readbuf = (char*)m_Buffer1, *writebuf = (char*)m_Buffer2;
    int dstopenflags=0, sourcefd=-1, destinationfd=-1;
    unsigned long startwriteoff = 0, totaldestsize = 0;
    bool adjust_dst_time = true, copy_xattrs = true, erase_xattrs = false, remember_choice = false;
    mode_t oldumask;
    __block unsigned long io_leftwrite = 0, io_totalread = 0, io_totalwrote = 0;
    __block bool io_docancel = false;
    
    assert(_path[strlen(_path)-1] != '/'); // sanity check
    
    // compose real src name
    strcpy(sourcepath, m_SourceDirectory);
    strcat(sourcepath, _path);
    
    // compose dest name
    if(m_CopyMode == CopyToFolder)
    {
        assert(m_Destination[strlen(m_Destination)-1] == '/'); // just a sanity check.
        strcpy(destinationpath, m_Destination);
        strcat(destinationpath, _path);
    }
    else
    {
        strcpy(destinationpath, m_Destination);
    }
    
    if(strcmp(sourcepath, destinationpath) == 0) return; // do not try to copy file into itself

opensource:
    if((sourcefd = open(sourcepath, O_RDONLY|O_SHLOCK)) == -1)
    {  // failed to open source file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:errno ForFile:sourcepath] WaitForResult];
        if(result == FileCopyOperationDR::Retry) goto opensource;
        if(result == FileCopyOperationDR::Skip) goto cleanup;
        if(result == FileCopyOperationDR::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { SetStopped(); goto cleanup; }
    }
    fcntl(sourcefd, F_NOCACHE, 1); // do not waste OS file cache with one-way data
    
statsource: // get information about source file
    if(fstat(sourcefd, &src_stat_buffer) == -1)
    {   // failed to stat source
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:errno ForFile:sourcepath] WaitForResult];
        if(result == FileCopyOperationDR::Retry) goto statsource;
        if(result == FileCopyOperationDR::Skip) goto cleanup;
        if(result == FileCopyOperationDR::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { SetStopped(); goto cleanup; }
    }

    // stat destination
    totaldestsize = src_stat_buffer.st_size;
    if(stat(destinationpath, &dst_stat_buffer) != -1)
    { // file already exist. what should we do now?
        int result;
        if(m_SkipAll) goto cleanup;
        if(m_OverwriteAll) goto decoverwrite;
        if(m_AppendAll) goto decappend;
  
        result = [[m_Operation OnFileExist:destinationpath
                                  newsize:src_stat_buffer.st_size
                                  newtime:src_stat_buffer.st_mtimespec.tv_sec
                                  exisize:dst_stat_buffer.st_size
                                  exitime:dst_stat_buffer.st_mtimespec.tv_sec
                                 remember:&remember_choice] WaitForResult];
        if(result == FileCopyOperationDR::Overwrite){ if(remember_choice) m_OverwriteAll = true;  goto decoverwrite; }
        if(result == FileCopyOperationDR::Append)   { if(remember_choice) m_AppendAll = true;     goto decappend;    }
        if(result == FileCopyOperationDR::Skip)     { if(remember_choice) m_SkipAll = true;       goto cleanup;      }
        if(result == OperationDialogResult::Stop)   { SetStopped(); goto cleanup; }
        
        // decisions about what to do with existing destination
    decoverwrite:
        dstopenflags = O_WRONLY;
        erase_xattrs = true;
        goto decend;
    decappend:
        dstopenflags = O_WRONLY;
        totaldestsize += dst_stat_buffer.st_size;
        startwriteoff = dst_stat_buffer.st_size;
        adjust_dst_time = false;
        copy_xattrs = false;
        goto decend;
    decend:;
    }
    else
    { // no dest file - just create it
        dstopenflags = O_WRONLY|O_CREAT;
    }
    
opendest: // open file descriptor for destination
    oldumask = umask(0); // we want to copy src permissions
    destinationfd = open(destinationpath, dstopenflags, src_stat_buffer.st_mode);
    umask(oldumask);
    
    if(destinationfd == -1)
    {   // failed to open destination file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantOpenDestFile:errno ForFile:destinationpath] WaitForResult];
        if(result == FileCopyOperationDR::Retry) goto opendest;
        if(result == FileCopyOperationDR::Skip) goto cleanup;
        if(result == FileCopyOperationDR::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { SetStopped(); goto cleanup; }
    }

    // preallocate space for data since we dont want to trash our disk
    if(src_stat_buffer.st_size > MIN_PREALLOC_SIZE)
    {
        fstore_t preallocstore = {F_ALLOCATECONTIG, F_PEOFPOSMODE, 0, src_stat_buffer.st_size};
        if(fcntl(destinationfd, F_PREALLOCATE, &preallocstore) == -1)
        {
            preallocstore.fst_flags = F_ALLOCATEALL;
            fcntl(destinationfd, F_PREALLOCATE, &preallocstore);
        }
    }
    fcntl(destinationfd, F_NOCACHE, 1); // caching is meaningless here?
    
dotruncate: // set right size for destination file
    if(ftruncate(destinationfd, totaldestsize) == -1)
    {   // failed to set dest file size
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyWriteError:errno ForFile:destinationpath] WaitForResult];
        if(result == FileCopyOperationDR::Retry) goto dotruncate;
        if(result == FileCopyOperationDR::Skip) goto cleanup;
        if(result == FileCopyOperationDR::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { SetStopped(); goto cleanup; }
    }

dolseek: // find right position in destination file
    if(lseek(destinationfd, startwriteoff, SEEK_SET) == -1)
    {   // failed seek in a file. lolwhat?
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyWriteError:errno ForFile:destinationpath] WaitForResult];
        if(result == FileCopyOperationDR::Retry) goto dolseek;
        if(result == FileCopyOperationDR::Skip) goto cleanup;
        if(result == FileCopyOperationDR::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { SetStopped(); goto cleanup; }
    }

    while(true)
    {
        __block ssize_t io_nread = 0;
        dispatch_group_async(m_IOGroup, m_ReadQueue, ^{
        doread:
            if(io_totalread < src_stat_buffer.st_size)
            {
                io_nread = read(sourcefd, readbuf, BUFFER_SIZE);
                if(io_nread == -1)
                {
                    if(m_SkipAll) {io_docancel = true; return;}
                    int result = [[m_Operation OnCopyReadError:errno ForFile:sourcepathp] WaitForResult];
                    if(result == FileCopyOperationDR::Retry) goto doread;
                    if(result == FileCopyOperationDR::Skip) {io_docancel = true; return;}
                    if(result == FileCopyOperationDR::SkipAll) {io_docancel = true; m_SkipAll = true; return;}
                    if(result == OperationDialogResult::Stop) { io_docancel = true; SetStopped(); return;}
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
                    int result = [[m_Operation OnCopyWriteError:errno ForFile:destinationpathp] WaitForResult];
                    if(result == FileCopyOperationDR::Retry) goto dowrite;
                    if(result == FileCopyOperationDR::Skip) {io_docancel = true; return;}
                    if(result == FileCopyOperationDR::SkipAll) {io_docancel = true; m_SkipAll = true; return;}
                    if(result == OperationDialogResult::Stop) { io_docancel = true; SetStopped(); return;}
                }
                alreadywrote += nwrite;
                io_leftwrite -= nwrite;
            }
            io_totalwrote += alreadywrote;
            m_TotalCopied += alreadywrote;
        });
        
        dispatch_group_wait(m_IOGroup, DISPATCH_TIME_FOREVER);
        if(io_docancel) goto cleanup;
        if(io_totalwrote == src_stat_buffer.st_size) break;
        
        io_leftwrite = io_nread;
        std::swap(readbuf, writebuf); // swap our work buffers - read buffer become write buffer and vice versa
        
        // update statistics
        SetProgress(double(m_TotalCopied) / double(m_SourceTotalBytes));
        //        uint64_t currenttime = mach_absolute_time();
        //        SetBytesPerSecond( double(totalwrote) / (double((currenttime - starttime)/1000000ul) / 1000.) );
    }
    
    // erase destination's xattrs
    if(erase_xattrs)
    {
        char *xnames = (char*) m_Buffer1;
        ssize_t xnamesizes = flistxattr(destinationfd, xnames, BUFFER_SIZE, 0);
        if(xnamesizes > 0)
        { // iterate and remove
            char *s = xnames, *e = xnames + xnamesizes;
            while(s < e)
            {
                fremovexattr(destinationfd, s, 0);
                s += strlen(s)+1;
            }
        }
    }
    
    // copy xattrs from src to dest
    if(copy_xattrs)
    {
        char *xnames = (char*) m_Buffer1;
        ssize_t xnamesizes = flistxattr(sourcefd, xnames, BUFFER_SIZE, 0);
        if(xnamesizes > 0)
        { // iterate and copy
            char *s = xnames, *e = xnames + xnamesizes;
            while(s < e)
            {
                ssize_t xattrsize = fgetxattr(sourcefd, s, m_Buffer2, BUFFER_SIZE, 0, 0);
                if(xattrsize >= 0) // xattr can be zero-length, just a tag itself
                    fsetxattr(destinationfd, s, m_Buffer2, xattrsize, 0, 0);
                s += strlen(s)+1;
            }
        }
    }
    
    // adjust destination time as source
    if(adjust_dst_time)
    {        
        struct attrlist attrs;
        memset(&attrs, 0, sizeof(attrs));
        attrs.bitmapcount = ATTR_BIT_MAP_COUNT;

        attrs.commonattr = ATTR_CMN_MODTIME;
        fsetattrlist(destinationfd, &attrs, &src_stat_buffer.st_mtimespec, sizeof(struct timespec), 0);

        attrs.commonattr = ATTR_CMN_CRTIME;
        fsetattrlist(destinationfd, &attrs, &src_stat_buffer.st_birthtimespec, sizeof(struct timespec), 0);
                
        attrs.commonattr = ATTR_CMN_ACCTIME;
        fsetattrlist(destinationfd, &attrs, &src_stat_buffer.st_atimespec, sizeof(struct timespec), 0);

        attrs.commonattr = ATTR_CMN_CHGTIME;
        fsetattrlist(destinationfd, &attrs, &src_stat_buffer.st_ctimespec, sizeof(struct timespec), 0);
    }
    
cleanup:
    if(sourcefd != -1) close(sourcefd);
    if(destinationfd != -1) close(destinationfd);
}

