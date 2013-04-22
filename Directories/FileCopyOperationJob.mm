//
//  FileCopyOperationJob.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 09.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileCopyOperationJob.h"
#import "filesysinfo.h"
#import <algorithm>
#import <sys/types.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <dirent.h>
#import <sys/time.h>
#import <sys/xattr.h>
#import <sys/attr.h>
#import <sys/vnode.h>
#import <sys/param.h>
#import <sys/mount.h>
#import <unistd.h>
#import <stdlib.h>

#define BUFFER_SIZE (512*1024) // 512kb
#define MIN_PREALLOC_SIZE (4096) // will try to preallocate files only if they are larger than 4k

// assumes that _fn1 is a valid file/dir name, or will return false immediately
// if _fn2 is not a valid path name will look at _fallback_second.
//  if _fallback_second is true this routine will go upper to the root until the valid path is reached
//  otherwise it will return false
// when two valid paths is achieved it calls FetchFileSystemRootFromPath and compares two roots
// TODO: how do we need to treat symlinks in this procedure?
static bool CheckSameVolume(const char *_fn1, const char*_fn2, bool &_same, bool _fallback_second = true)
{
    // accept only full paths
    assert(_fn1[0]=='/');
    assert(_fn2[0]=='/');
    
    struct stat st;
    if(stat(_fn1, &st) == -1)
        return false;
 
    char fn2[MAXPATHLEN];
    strcpy(fn2, _fn2);

    while(stat(fn2, &st) == -1)
    {
        if(!_fallback_second)
            return false;
        
        assert(fn2[1] != 0);   // that is an absolutely weird case if can't access "/" path.
                               // in this situation it's better to stop working at all

        char *s = strrchr(fn2, '/');
        if(s == fn2)
            s++; // non regular case for topmost entries

        *s = 0;
    }

    char root1[MAXPATHLEN], root2[MAXPATHLEN];
    if(FetchFileSystemRootFromPath(_fn1, root1) != 0) return false;
    if(FetchFileSystemRootFromPath(fn2, root2) != 0) return false;

    _same = strcmp(root1, root2) == 0;

    return true;
}

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
    m_IsSingleFileCopy(true),
    m_SameVolume(false),
    m_IsSingleEntryCopy(false)
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
                         FileCopyOperationOptions* _opts,
                         FileCopyOperation *_op
                         )
{
    m_Operation = _op;
    m_InitialItems = _files;
    m_IsCopying = _opts->docopy;
    strcpy(m_Destination, _dest);
    strcpy(m_SourceDirectory, _root);
}

void FileCopyOperationJob::Do()
{
    m_IsSingleEntryCopy = m_InitialItems->CountStringsWithDescendants() == 1;
    
    // this will analyze what user wants from us
    ScanDestination();
    if(CheckPauseOrStop()) { SetStopped(); return; }

    
    if(m_WorkMode == CopyToFile || m_WorkMode == CopyToFolder || m_WorkMode == MoveToFile || m_WorkMode == MoveToFolder )
    {
        ScanItems();
        if(CheckPauseOrStop()) { SetStopped(); return; }
    }
    else
    {
        assert(m_WorkMode == RenameToFile || m_WorkMode == RenameToFolder);
        // renaming is trivial, don't scan source it deeply - we need just a top level
        m_ScannedItems = m_InitialItems;
        m_InitialItems = 0;
    }

    // we don't need it any more - so free memory as soon as possible
    if(m_InitialItems)
        FlexChainedStringsChunk::FreeWithDescendants(&m_InitialItems);

    if(m_WorkMode == CopyToFile || m_WorkMode == CopyToFolder || m_WorkMode == MoveToFile || m_WorkMode == MoveToFolder  )
    {
        // allocate buffers and queues only when we'll need them
        m_Buffer1 = malloc(BUFFER_SIZE);
        m_Buffer2 = malloc(BUFFER_SIZE);
        m_ReadQueue = dispatch_queue_create(0, 0);
        m_WriteQueue = dispatch_queue_create(0, 0);
        m_IOGroup = dispatch_group_create();
    }

    ProcessItems();
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
    char destpath[MAXPATHLEN];    
    if(stat(m_Destination, &stat_buffer) == 0)
    {
        CheckSameVolume(m_SourceDirectory, m_Destination, m_SameVolume);        
        bool isfile = (stat_buffer.st_mode&S_IFMT) == S_IFREG;
        bool isdir  = (stat_buffer.st_mode&S_IFMT) == S_IFDIR;
        
        if(isfile)
        {
            if(m_IsCopying)
            {
                m_WorkMode = CopyToFile;
            }
            else
            {
                if(m_SameVolume) m_WorkMode = RenameToFile;
                else             m_WorkMode = MoveToFile;
            }
        }
        else if(isdir)
        {   
            if(m_Destination[strlen(m_Destination)-1] != '/')
                strcat(m_Destination, "/"); // add slash at the end

            if(m_IsCopying)
            {
                m_WorkMode = CopyToFolder;
            }
            else
            {
                if(m_SameVolume) m_WorkMode = RenameToFolder;
                else             m_WorkMode = MoveToFolder;
            }
        }
        else
            assert(0); //TODO: implement handling of this weird cases (like copying to a device)
    }
    else
    { // ok, it's not a valid entry, now we have to analyze what user wants from us
        // and try to combine the right m_Destination
        if(strchr(m_Destination, '/') == 0)
        {
            // there's no directories mentions in destination path, let's treat destination as an regular absent file
            // let's think that this destination file should be located in source directory
            // TODO: add CheckSameVolume
            strcpy(destpath, m_SourceDirectory);
            strcat(destpath, m_Destination);
            strcpy(m_Destination, destpath);
            
            m_SameVolume = true;
            if(m_IsCopying) m_WorkMode = CopyToFile;
            else            m_WorkMode = RenameToFile;
        }
        else
        {            
            if(m_Destination[strlen(m_Destination)-1] == '/' )
            {
                // user want to copy/rename/move file(s) to some directory, like "Abra/Carabra/" or "/bin/abra/"
                if(m_Destination[0] != '/')
                { // relative to source directory
                    strcpy(destpath, m_SourceDirectory);
                    strcat(destpath, m_Destination);
                    strcpy(m_Destination, destpath);

                    // check if the volume is the same
                    // TODO: there can be some CRAZY situations when user wants to do someting with directory that
                    // contains a mounting point with another filesystem. but for now let's think that is not valid.
                    // for the future - algo should have a flag about nested filesystems and process them carefully later
                    CheckSameVolume(m_SourceDirectory, m_Destination, m_SameVolume);
                }
                else
                { // absolute path                
                    CheckSameVolume(m_SourceDirectory, m_Destination, m_SameVolume);// TODO: look up
                }

                if(m_IsCopying)
                {
                    m_WorkMode = CopyToFolder;
                }
                else
                {
                    if(m_SameVolume)  m_WorkMode = RenameToFolder;
                    else              m_WorkMode = MoveToFolder;
                }
            
                // now we need to check every directory here and create them they are not exist
                BuildDestinationDirectory(m_Destination);
                if(CheckPauseOrStop()) return;
            }
            else
            { // user want to copy/rename/move file(s) to some filename, like "Abra/Carabra" or "/bin/abra"
                if(m_Destination[0] != '/')
                { // relative to source directory
                    strcpy(destpath, m_SourceDirectory);
                    strcat(destpath, m_Destination);
                    strcpy(m_Destination, destpath);
                }
                else
                { // absolute path
                }
                CheckSameVolume(m_SourceDirectory, m_Destination, m_SameVolume);// TODO: look up

                if(m_IsCopying)
                {
                    m_WorkMode = CopyToFile;
                }
                else
                {
                    if(m_SameVolume) m_WorkMode = RenameToFile;
                    else             m_WorkMode = MoveToFile;
                }
                
                // now we need to check every directory here and create them they are not exist
                BuildDestinationDirectory(m_Destination);
                if(CheckPauseOrStop()) return;
            }
        }
    }
}

void FileCopyOperationJob::BuildDestinationDirectory(const char* _path)
{
    // TODO: not very efficient implementation, it does many redundant stat calls
    // this algorithm iterates from left to right, but it's better to iterate right-left and then left-right
    // but this work is doing only once per MassCopyOp, so user may not even notice this issue
    
    struct stat stat_buffer;
    char destpath[MAXPATHLEN];
    strcpy(destpath, _path);
    char* leftmost = strchr(destpath+1, '/');
    assert(leftmost != 0);
    do
    {
        *leftmost = 0;
        if(stat(destpath, &stat_buffer) == -1)
        {
            // absent part - need to create it
domkdir:    if(mkdir(destpath, 0777) == -1)
            {
                int result = [[m_Operation OnDestCantCreateDir:errno ForDir:destpath] WaitForResult];
                if (result == OperationDialogResult::Retry) goto domkdir;
                if (result == OperationDialogResult::Stop) { RequestStop(); return; }
            }
        }
        *leftmost = '/';
        
        leftmost = strchr(leftmost+1, '/');
    } while(leftmost != 0);
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

        if(CheckPauseOrStop()) return;
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

        if(CheckPauseOrStop()) return;
    }

    if(!m_FilesToDelete.empty())
        ProcessFilesRemoval();
    if(!m_DirsToDelete.empty())
        ProcessFoldersRemoval();
}

void FileCopyOperationJob::ProcessItem(const FlexChainedStringsChunk::node *_node)
{
    assert(_node->len != 0);
    
    // compose file name - reverse lookup
    char itemname[MAXPATHLEN];
    _node->str_with_pref(itemname);
    bool src_isdir = _node->str()[_node->len-1] == '/'; // found if item is a directory    
    
    if(m_WorkMode == CopyToFolder || m_WorkMode == CopyToFile)
    {
        if(src_isdir)   ProcessDirectoryCopying(itemname);
        else            ProcessFileCopying(itemname);
    }
    else if(m_WorkMode == RenameToFile)
        ProcessRenameToFile(itemname);
    else if(m_WorkMode == RenameToFolder)
        ProcessRenameToFolder(itemname);
    else if(m_WorkMode == MoveToFolder)
        ProcessMoveToFolder(itemname, src_isdir);
    else if(m_WorkMode == MoveToFile)
        ProcessMoveToFile(itemname, src_isdir);
    else assert(0); // sanity guard
}

void FileCopyOperationJob::ProcessFilesRemoval()
{
    for(auto i: m_FilesToDelete)
    {
        assert(i->str()[i->len-1] != '/'); // sanity check
        
        char itemname[MAXPATHLEN], path[MAXPATHLEN];
        i->str_with_pref(itemname);
        strcpy(path, m_SourceDirectory);
        strcat(path, itemname);
        unlink(path); // any error handling here?
    }
}

void FileCopyOperationJob::ProcessFoldersRemoval()
{
    for(auto i = m_DirsToDelete.rbegin(); i != m_DirsToDelete.rend(); ++i)
    {
        const auto item = *i;
        assert(item->str()[item->len-1] == '/'); // sanity check
        
        char itemname[MAXPATHLEN], path[MAXPATHLEN];
        item->str_with_pref(itemname);
        strcpy(path, m_SourceDirectory);
        strcat(path, itemname);
        rmdir(path); // any error handling here?
    }
}

void FileCopyOperationJob::ProcessMoveToFile(const char *_path, bool _is_dir)
{
    // m_Destination is a file name
    char sourcepath[MAXPATHLEN];
    if(!_is_dir)
    {
        assert(_path[strlen(_path)-1] != '/'); // sanity check
        // compose real src name
        strcpy(sourcepath, m_SourceDirectory);
        strcat(sourcepath, _path);
        
        // compose dest name        
        if( CopyFileTo(sourcepath, m_Destination) )
            m_FilesToDelete.push_back(m_CurrentlyProcessingItem);
            // put files in deletion list only if copying was successful        
    }
    else
    {
        assert(_path[strlen(_path)-1] == '/'); // sanity check
        // compose real src name
        strcpy(sourcepath, m_SourceDirectory);
        strcat(sourcepath, _path);

        if(CopyDirectoryTo(sourcepath, m_Destination))
            m_DirsToDelete.push_back(m_CurrentlyProcessingItem);
            // put dirs in deletion list only if copying was successful
    }
}

void FileCopyOperationJob::ProcessMoveToFolder(const char *_path, bool _is_dir)
{
    // m_Destination is a directory path
    char sourcepath[MAXPATHLEN], destinationpath[MAXPATHLEN];
    
    if(!_is_dir)
    {
        assert(_path[strlen(_path)-1] != '/'); // sanity check
        // compose real src name
        strcpy(sourcepath, m_SourceDirectory);
        strcat(sourcepath, _path);
    
        // compose dest name
        assert(m_Destination[strlen(m_Destination)-1] == '/'); // just a sanity check.
        strcpy(destinationpath, m_Destination);
        strcat(destinationpath, _path);
        assert(strcmp(sourcepath, destinationpath) != 0); // this situation should never happen
    
        if( CopyFileTo(sourcepath, destinationpath) )
        {
            // put files in deletion list only if copying was successful
            m_FilesToDelete.push_back(m_CurrentlyProcessingItem);
        }
    }
    else
    {
        assert(_path[strlen(_path)-1] == '/'); // sanity check
        // compose real src name
        strcpy(sourcepath, m_SourceDirectory);
        strcat(sourcepath, _path);
        
        // compose dest name
        assert(m_Destination[strlen(m_Destination)-1] == '/'); // just a sanity check.
        strcpy(destinationpath, m_Destination);
        strcat(destinationpath, _path);
        assert(strcmp(sourcepath, destinationpath) != 0); // this situation should never happen
        
        if(CopyDirectoryTo(sourcepath, destinationpath))
        {
            m_DirsToDelete.push_back(m_CurrentlyProcessingItem);
        }
    }
}

void FileCopyOperationJob::ProcessRenameToFile(const char *_path)
{
    // m_Destination is full target path - we need to rename current file to it
    // assuming that we're working on same valume
    char sourcepath[MAXPATHLEN];
    struct stat stat_buffer;    
    
     // sanity checks
    assert(m_Destination[strlen(m_Destination)-1] != '/');
    assert(_path[0] != 0);
    assert(_path[0] != '/');
    
    // compose real src name
    strcpy(sourcepath, m_SourceDirectory);
    strcat(sourcepath, _path);
    
    int ret = lstat(m_Destination, &stat_buffer);
    if(ret != -1)
    {
        // TODO: target file already exist. ask user about what to do
        assert(0);
    }
    
    ret = rename(sourcepath, m_Destination);
    // TODO: handle result
    assert(ret == 0);
}

void FileCopyOperationJob::ProcessRenameToFolder(const char *_path)
{
    // m_Destination is a directory path - we need to appen _path to it
    char sourcepath[MAXPATHLEN], destpath[MAXPATHLEN];
    struct stat stat_buffer;

    assert(_path[0] != 0);
    assert(_path[0] != '/');
        
    // compose real src name
    strcpy(sourcepath, m_SourceDirectory);
    strcat(sourcepath, _path);
    
    strcpy(destpath, m_Destination);
    if(destpath[strlen(destpath)-1] != '/' ) strcat(destpath, "/");
    strcat(destpath, _path);
    
    int ret = lstat(destpath, &stat_buffer);
    if(ret != -1)
    {
        // TODO: target file already exist. ask user about what to do
        assert(0);
    }

    ret = rename(sourcepath, destpath);
    // TODO: handle result
    assert(ret == 0);
}

void FileCopyOperationJob::ProcessDirectoryCopying(const char *_path)
{
    if(m_WorkMode == CopyToFolder)
    {
        assert(m_Destination[strlen(m_Destination)-1] == '/');
        assert(_path[strlen(_path)-1] == '/');
    
        char src[MAXPATHLEN], dest[MAXPATHLEN];
        strcpy(dest, m_Destination);
        strcat(dest, _path);

        strcpy(src, m_SourceDirectory);
        strcat(src, _path);

        CopyDirectoryTo(src, dest);
    }
    else if(m_WorkMode == CopyToFile)
    {
        assert(m_Destination[strlen(m_Destination)-1] != '/');
        assert(_path[strlen(_path)-1] == '/');

        char src[MAXPATHLEN], dest[MAXPATHLEN];

        strcpy(dest, m_Destination);
        // here we need to find if user wanted just to copy a single top-level directory
        // if so - don't touch destination name. otherwise - add an original path there
        if(m_IsSingleEntryCopy)
        {
            // for top level we need to just leave path without changes - skip top level's entry name
            // for nested entries we need to cut first part of a path
            if(*(strchr(_path, '/')+1) != 0)
                strcat(dest, strchr(_path, '/'));
        }
        else
        {
            strcat(dest, "/");
            strcat(dest, _path);
        }
        
        strcpy(src, m_SourceDirectory);
        strcat(src, _path);
        
        CopyDirectoryTo(src, dest);
    }
    else assert(0);
}

bool FileCopyOperationJob::CopyDirectoryTo(const char *_src, const char *_dest)
{
    // TODO: need to handle errors on attributes somehow. but I don't know how.
    struct stat src_stat, dst_stat;
    bool opres = false;
    int src_fd = -1, dst_fd = -1;
    char *xnames;
    ssize_t xnamesizes;

    // check if target already exist
    if( lstat(_dest, &dst_stat) != -1 )
    {
        // target exists; check that it's a directory

        if( (dst_stat.st_mode & S_IFMT) != S_IFDIR )
        {
            // TODO: ask user what to do
            goto end;
        }
    }
    else
    {
domkdir:
        if(mkdir(_dest, 0777))
        {
            if(m_SkipAll) goto end;
            int result = [[m_Operation OnCopyCantCreateDir:errno ForDir:_dest] WaitForResult];
            if(result == OperationDialogResult::Retry) goto domkdir;
            if(result == OperationDialogResult::Skip) goto end;
            if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto end;}
            if(result == OperationDialogResult::Stop)  { RequestStop(); goto end; }
        }
    }

    // do attributes stuff
    if((src_fd = open(_src, O_RDONLY)) == -1) goto end;
    if((dst_fd = open(_dest, O_RDONLY)) == -1) goto end;
    if(fstat(src_fd, &src_stat) != 0) goto end;
    
    // change unix mode
    fchmod(dst_fd, src_stat.st_mode);

    // change ownage
    fchown(dst_fd, src_stat.st_uid, src_stat.st_gid);

    // change flags
    fchflags(dst_fd, src_stat.st_flags);
    
    // copy xattrs
    assert(m_Buffer1 != 0);
    xnames = (char*) m_Buffer1;
    xnamesizes = flistxattr(src_fd, xnames, BUFFER_SIZE, 0);
    if(xnamesizes > 0)
    { // iterate and copy
        char *s = xnames, *e = xnames + xnamesizes;
        while(s < e)
        {
            ssize_t xattrsize = fgetxattr(src_fd, s, m_Buffer2, BUFFER_SIZE, 0, 0);
            if(xattrsize >= 0) // xattr can be zero-length, just a tag itself
                fsetxattr(dst_fd, s, m_Buffer2, xattrsize, 0, 0);
            s += strlen(s)+1;
        }
    }
    
    // adjust destination times
    {
        struct attrlist attrs;
        memset(&attrs, 0, sizeof(attrs));
        attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
        
        attrs.commonattr = ATTR_CMN_MODTIME;
        fsetattrlist(dst_fd, &attrs, &src_stat.st_mtimespec, sizeof(struct timespec), 0);
        
        attrs.commonattr = ATTR_CMN_CRTIME;
        fsetattrlist(dst_fd, &attrs, &src_stat.st_birthtimespec, sizeof(struct timespec), 0);
        
        attrs.commonattr = ATTR_CMN_ACCTIME;
        fsetattrlist(dst_fd, &attrs, &src_stat.st_atimespec, sizeof(struct timespec), 0);
        
        attrs.commonattr = ATTR_CMN_CHGTIME;
        fsetattrlist(dst_fd, &attrs, &src_stat.st_ctimespec, sizeof(struct timespec), 0);
    }

    opres = true;
end:
    if(src_fd != -1) close(src_fd);
    if(dst_fd != -1) close(dst_fd);
    return opres;
}

void FileCopyOperationJob::ProcessFileCopying(const char *_path)
{    
    char sourcepath[MAXPATHLEN], destinationpath[MAXPATHLEN];

    assert(_path[strlen(_path)-1] != '/'); // sanity check

    // compose real src name
    strcpy(sourcepath, m_SourceDirectory);
    strcat(sourcepath, _path);
    
    // compose dest name
    if(m_WorkMode == CopyToFolder)
    {
        assert(m_Destination[strlen(m_Destination)-1] == '/'); // just a sanity check.
        strcpy(destinationpath, m_Destination);
        strcat(destinationpath, _path);
    }
    else
    {
        strcpy(destinationpath, m_Destination);
        // here we need to find if user wanted just to copy a single top-level directory
        // if so - don't touch destination name. otherwise - add an original path there
        if(m_IsSingleEntryCopy)
        {
            // for top level we need to just leave path without changes - skip top level's entry name
            // for nested entries we need to cut first part of a path
            if(strchr(_path, '/') != 0)
                strcat(destinationpath, strchr(_path, '/'));
        }
    }
    
    if(strcmp(sourcepath, destinationpath) == 0) return; // do not try to copy file into itself

    CopyFileTo(sourcepath, destinationpath);
}

bool FileCopyOperationJob::CopyFileTo(const char *_src, const char *_dest)
{
    assert(m_WorkMode != RenameToFile && m_WorkMode != RenameToFolder); // sanity check
    
    // TODO: need to ask about destination volume info to exclude meaningless operations for attrs which are not supported
    // TODO: need to adjust buffer sizes and writing calls to preffered volume's I/O size
    struct stat src_stat_buffer, dst_stat_buffer;
    char *readbuf = (char*)m_Buffer1, *writebuf = (char*)m_Buffer2;
    int dstopenflags=0, sourcefd=-1, destinationfd=-1;
    unsigned long startwriteoff = 0, totaldestsize = 0, dest_sz_on_stop = 0;
    bool adjust_dst_time = true, copy_xattrs = true, erase_xattrs = false, remember_choice = false,
    was_successful = false, unlink_on_stop = false;
    mode_t oldumask;
    __block unsigned long io_leftwrite = 0, io_totalread = 0, io_totalwrote = 0;
    __block bool io_docancel = false;
    
opensource:
    if((sourcefd = open(_src, O_RDONLY|O_SHLOCK)) == -1)
    {  // failed to open source file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:errno ForFile:_src] WaitForResult];
        if(result == OperationDialogResult::Retry) goto opensource;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    fcntl(sourcefd, F_NOCACHE, 1); // do not waste OS file cache with one-way data
    
statsource: // get information about source file
    if(fstat(sourcefd, &src_stat_buffer) == -1)
    {   // failed to stat source
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:errno ForFile:_src] WaitForResult];
        if(result == OperationDialogResult::Retry) goto statsource;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
    // stat destination
    totaldestsize = src_stat_buffer.st_size;
    if(stat(_dest, &dst_stat_buffer) != -1)
    { // file already exist. what should we do now?
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
        goto decend;
    decappend:
        dstopenflags = O_WRONLY;
        totaldestsize += dst_stat_buffer.st_size;
        startwriteoff = dst_stat_buffer.st_size;
        dest_sz_on_stop = dst_stat_buffer.st_size;
        adjust_dst_time = false;
        copy_xattrs = false;
        unlink_on_stop = false;
        goto decend;
    decend:;
    }
    else
    { // no dest file - just create it
        dstopenflags = O_WRONLY|O_CREAT;
        unlink_on_stop = true;
        dest_sz_on_stop = 0;
    }
    
opendest: // open file descriptor for destination
    oldumask = umask(0); // we want to copy src permissions
    destinationfd = open(_dest, dstopenflags, src_stat_buffer.st_mode);
    umask(oldumask);
    
    if(destinationfd == -1)
    {   // failed to open destination file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantOpenDestFile:errno ForFile:_dest] WaitForResult];
        if(result == OperationDialogResult::Retry) goto opendest;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
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
        int result = [[m_Operation OnCopyWriteError:errno ForFile:_dest] WaitForResult];
        if(result == OperationDialogResult::Retry) goto dotruncate;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
dolseek: // find right position in destination file
    if(lseek(destinationfd, startwriteoff, SEEK_SET) == -1)
    {   // failed seek in a file. lolwhat?
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyWriteError:errno ForFile:_dest] WaitForResult];
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
            if(io_totalread < src_stat_buffer.st_size)
            {
                io_nread = read(sourcefd, readbuf, BUFFER_SIZE);
                if(io_nread == -1)
                {
                    if(m_SkipAll) {io_docancel = true; return;}
                    int result = [[m_Operation OnCopyReadError:errno ForFile:_dest] WaitForResult];
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
        if(io_totalwrote == src_stat_buffer.st_size) break;
        
        io_leftwrite = io_nread;
        std::swap(readbuf, writebuf); // swap our work buffers - read buffer become write buffer and vice versa
        
        // update statistics
        SetProgress(double(m_TotalCopied) / double(m_SourceTotalBytes));
        //        uint64_t currenttime = mach_absolute_time();
        //        SetBytesPerSecond( double(totalwrote) / (double((currenttime - starttime)/1000000ul) / 1000.) );
    }
    
    // TODO: do we need to determine if various attributes setting was successful?
    
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
    
    // change ownage
    fchown(destinationfd, src_stat_buffer.st_uid, src_stat_buffer.st_gid);
    
    // change flags
    fchflags(destinationfd, src_stat_buffer.st_flags);
    
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
    
    was_successful = true;

cleanup:
    if(sourcefd != -1) close(sourcefd);
    if(!was_successful && destinationfd != -1)
    {
        // we need to revert what we've done
        ftruncate(destinationfd, dest_sz_on_stop);
        close(destinationfd);
        destinationfd = -1;
        if(unlink_on_stop)
            unlink(_dest);
    }
    if(destinationfd != -1) close(destinationfd);
    return was_successful;
}