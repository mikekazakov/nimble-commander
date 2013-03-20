//
//  FileOpMassCopy.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 12.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "FileOpMassCopy.h"
#include "PanelData.h"
#include "MessageBox.h"
#include "MainWindowController.h"
#include "FileAlreadyExistSheetController.h"
#include <sys/types.h>
#include <sys/dirent.h>
#include <sys/stat.h>
#include <dirent.h>
#include <sys/time.h>
#include <sys/xattr.h>
#include <algorithm>
#include "Common.h"

#define BUFFER_SIZE (512*1024) // 512kb
#define MIN_PREALLOC_SIZE (4096) // will try to preallocate files only if they are larger than 4k

static void SleepForSomeTime()
{
    usleep(50000); // 50 millisec
}

// user interaction helpers, to keep main code as clean as posible
static int DoFileAlreadyExistSheetController(NSWindow *_wnd, char *_destpath, struct stat &_new, struct stat _old, bool *_remember)
{
    FileAlreadyExistSheetController *fa;
    __block volatile int ret = 0;
    
    fa = [[FileAlreadyExistSheetController alloc] init];
    [fa ShowSheet:_wnd
         destpath:[NSString stringWithUTF8String:_destpath]
          newsize:_new.st_size
          newtime:_new.st_mtimespec.tv_sec
          exisize:_old.st_size
          exitime:_old.st_mtimespec.tv_sec
          handler:^(int _ret, bool _r){
              ret = _ret;
              *_remember = _r;
          }];

    while(!ret) SleepForSomeTime();
    return ret;
}

static int DoMessageBoxRetrySkipSkipallCancel_WithText(NSString *_text1, NSString *_text2, NSWindow *_wnd)
{
    volatile int ret = 0;
    MessageBox* mb = [MessageBox new];
    [mb setAlertStyle:NSCriticalAlertStyle];
    [mb setMessageText:_text1];
    [mb setInformativeText:_text2];
    [mb addButtonWithTitle:@"Retry"];
    [mb addButtonWithTitle:@"Skip"];
    [mb addButtonWithTitle:@"Skip all"];
    [mb addButtonWithTitle:@"Cancel"];
    [mb ShowSheet:_wnd ptr:&ret];
    
    while(!ret) SleepForSomeTime();
    if(ret == NSAlertFirstButtonReturn) return DialogResult::Retry;
    if(ret == NSAlertSecondButtonReturn) return DialogResult::Skip;
    if(ret == NSAlertThirdButtonReturn) return DialogResult::SkipAll;
    if(ret == NSAlertThirdButtonReturn+1) return DialogResult::Cancel;
    assert(0);
}

static int DoMessageBoxRetryCancel_WithText(NSString *_text1, NSString *_text2, NSWindow *_wnd)
{
    volatile int ret = 0;    
    MessageBox* mb = [MessageBox new];
    [mb setAlertStyle:NSCriticalAlertStyle];
    [mb setMessageText:_text1];
    [mb setInformativeText:_text2];
    [mb addButtonWithTitle:@"Retry"];
    [mb addButtonWithTitle:@"Cancel"];
    [mb ShowSheet:_wnd ptr:&ret];
    
    while(!ret) SleepForSomeTime();
    if(ret == NSAlertFirstButtonReturn) return DialogResult::Retry;
    if(ret == NSAlertSecondButtonReturn) return DialogResult::Cancel;
    assert(0);
}

static int DoMessageBoxRetrySkipSkipallCancel_CannotAccessSourceFile(const char *_path, NSWindow *_wnd, int _err)
{
    NSString *text1 = [@"Cannot access source file: " stringByAppendingString: [NSString stringWithUTF8String:_path] ];
    NSString *text2 = [NSString stringWithUTF8String:strerror(_err)];
    return DoMessageBoxRetrySkipSkipallCancel_WithText(text1, text2, _wnd);
}

static int DoMessageBoxRetrySkipSkipallCancel_CannotOpenDestinationFile(const char *_path, NSWindow *_wnd, int _err)
{
    NSString *text1 = [@"Cannot open destination file: " stringByAppendingString: [NSString stringWithUTF8String:_path] ];
    NSString *text2 = [NSString stringWithUTF8String:strerror(_err)];
    return DoMessageBoxRetrySkipSkipallCancel_WithText(text1, text2, _wnd);
}

static int DoMessageBoxRetrySkipSkipallCancel_ReadError(const char *_path, NSWindow *_wnd, int _err)
{
    NSString *text1 = [@"Read error at " stringByAppendingString: [NSString stringWithUTF8String:_path] ];
    NSString *text2 = [NSString stringWithUTF8String:strerror(_err)];
    return DoMessageBoxRetrySkipSkipallCancel_WithText(text1, text2, _wnd);
}

static int DoMessageBoxRetrySkipSkipallCancel_WriteError(const char *_path, NSWindow *_wnd, int _err)
{
    NSString *text1 = [@"Write error at " stringByAppendingString: [NSString stringWithUTF8String:_path] ];
    NSString *text2 = [NSString stringWithUTF8String:strerror(_err)];
    return DoMessageBoxRetrySkipSkipallCancel_WithText(text1, text2, _wnd);
}

static int DoMessageBoxRetryCancel_CantCreateDir(const char *_path, NSWindow *_wnd, int _err)
{
    NSString *text1 = [@"Can't create directory " stringByAppendingString: [NSString stringWithUTF8String:_path] ];
    NSString *text2 = [NSString stringWithUTF8String:strerror(_err)];
    return DoMessageBoxRetryCancel_WithText(text1, text2, _wnd);
}

static int DoMessageBoxRetrySkipSkipAllCancel_CantCreateDir(const char *_path, NSWindow *_wnd, int _err)
{
    NSString *text1 = [@"Can't create directory " stringByAppendingString: [NSString stringWithUTF8String:_path] ];
    NSString *text2 = [NSString stringWithUTF8String:strerror(_err)];
    return DoMessageBoxRetrySkipSkipallCancel_WithText(text1, text2, _wnd);
}


FileOpMassCopy::FileOpMassCopy():
    m_Wnd(0),
    m_InitialItems(0),
    m_ScannedItems(0),
    m_SourceNumberOfFiles(0),
    m_SourceNumberOfDirectories(0),
    m_SourceTotalBytes(0),
    m_ScannedItemsLast(0),
    m_CopyMode(CopyUnknown),
    m_SkipAll(false),
    m_Cancel(false),
    m_OverwriteAll(false),
    m_AppendAll(false),
    m_Buffer1(0),
    m_Buffer2(0),
    m_TotalCopied(0),
    m_OpState(StateScanning),
    m_CurrentlyProcessingItem(0)
{
    // in xattr operations we'll use our big Buf1 and Buf2 - they should be quite enough
    // in OS X 10.4-10.6 maximum size of xattr value was 4Kb
    // in OS X 10.7(or in 10.8?) it was increased to 128Kb    
    assert( BUFFER_SIZE >= 128 * 1024 ); // should be enough to hold any xattr value
}

FileOpMassCopy::~FileOpMassCopy()
{
}

void FileOpMassCopy::InitOpDataWithPanel(const PanelData&_source, const char *_dest, MainWindowController *_wnd)
{
    m_Wnd = _wnd;
    m_InitialItems = FlexChainedStringsChunk::Allocate();
    FlexChainedStringsChunk *last = m_InitialItems;
    
    // TODO: consider if we need to iterate in current sorting mode
    int i = 0, e = (int)_source.DirectoryEntries().size();
    for(;i!=e;++i)
    {
        const auto &item = _source.DirectoryEntries()[i];
        if(item.cf_isselected())
            last = last->AddString(item.namec(), item.namelen, 0);
    }
    
    strcpy(m_Destination, _dest);
    _source.GetDirectoryPathWithTrailingSlash(m_SourceDirectory);
}

void FileOpMassCopy::Run()
{
    dispatch_queue_t queue = dispatch_queue_create(0, 0);
    dispatch_async(queue,^
                   {
                       DoRun();
                       DoCleanup();
                       usleep(300000); // give a user 0.3sec to see that we're done
                       SetReadyToPurge();
                   });
}

FileOpMassCopy::OpState FileOpMassCopy::State() const
{
    return m_OpState;
}

const FlexChainedStringsChunk::node *FileOpMassCopy::CurrentlyProcessingItem() const
{
    return m_CurrentlyProcessingItem;
}

void FileOpMassCopy::DoRun()
{
    if(!ScanDestination())
        return ;
    ScanItems();

    // we don't need any more - so free memory as soon as possible
    FlexChainedStringsChunk::FreeWithDescendants(&m_InitialItems);
 
    m_Buffer1 = malloc(BUFFER_SIZE);
    m_Buffer2 = malloc(BUFFER_SIZE);
    m_ReadQueue = dispatch_queue_create(0, 0);
    m_WriteQueue = dispatch_queue_create(0, 0);
    m_IOGroup = dispatch_group_create();
    m_OpState = StateCopying;
    ProcessItems();
    m_CurrentlyProcessingItem = 0;
}

void FileOpMassCopy::DoCleanup()
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

bool FileOpMassCopy::ScanItems()
{
    // iterate in original filenames
    int sn = 0;
    FlexChainedStringsChunk *current = m_InitialItems;
    m_ScannedItems = FlexChainedStringsChunk::Allocate();
    m_ScannedItemsLast = m_ScannedItems;
    
    while(true)
    {
        if(sn == FlexChainedStringsChunk::strings_per_chunk && current->next != 0)
        {
            sn = 0;
            current = current->next;
            continue;
        }

        if( current->amount == sn )
            break;

        if( !ScanItem(current->strings[sn].str(), current->strings[sn].str(), 0) )
            return false;
        
        sn++;
    }
    
    return true;
}

bool FileOpMassCopy::ScanItem(const char *_full_path, const char *_short_path, const FlexChainedStringsChunk::node *_prefix)
{
    // TODO: optimize it ALL!
    // TODO: this path composing can be optimized
    // DANGER: this big buffer can cause stack overflow since ScanItem function is used recursively. FIXME!!!
    // 512Kb for threads in OSX. CHECK ME!
    char fullpath[__DARWIN_MAXPATHLEN];
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
            char dirpath[__DARWIN_MAXPATHLEN];
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
                    
                    if(!ScanItem(dirpath, entp->d_name, dirnode))
                    {
                        // ???
                        break;
                    }
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

    
    return true;
}

bool FileOpMassCopy::ScanDestination()
{
    struct stat stat_buffer;
    if(stat(m_Destination, &stat_buffer) == 0)
    {
        bool isfile = (stat_buffer.st_mode&S_IFMT) == S_IFREG;
        bool isdir  = (stat_buffer.st_mode&S_IFMT) == S_IFDIR;
        
        if(isfile)
            m_CopyMode = CopyToFile;
        else if(isdir)
            m_CopyMode = CopyToFolder;
        else
            assert(0); //TODO: implement handling of this weird cases
    }
    else
    { // ok, it's not a valid entry, now we have to analyze what user wants from us
        if(strchr(m_Destination, '/') == 0)
        {   // there's no directories mentions in destination path, let's treat destination as an regular absent file
            // let's think that this destination file should be located in source directory
            char destpath[__DARWIN_MAXPATHLEN];
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
                char destpath[__DARWIN_MAXPATHLEN];
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
            
            char destpath[__DARWIN_MAXPATHLEN];
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
                        switch (DoMessageBoxRetryCancel_CantCreateDir(destpath, [m_Wnd window], errno))
                        {
                            case DialogResult::Retry: goto domkdir;
                            case DialogResult::Cancel: m_Cancel = true; return false;
                        }
                    }
                }
                *leftmost = '/';
                
                leftmost = strchr(leftmost+1, '/');
            } while(leftmost != 0);
        }
    }

    return true;
}

void FileOpMassCopy::ProcessItems()
{
    int sn = 0;
    FlexChainedStringsChunk *current = m_ScannedItems;
    
    while(true)
    {
        if(sn == FlexChainedStringsChunk::strings_per_chunk && current->next != 0)
        {
            sn = 0;
            current = current->next;
            continue;
        }
        
        if( current->amount == sn )
            break;
        
        m_CurrentlyProcessingItem = &current->strings[sn];
        ProcessItem(m_CurrentlyProcessingItem);
        if(m_Cancel)
            break;

        sn++;
    }
}

void FileOpMassCopy::ProcessItem(const FlexChainedStringsChunk::node *_node)
{
// TODO: stats for all this stuff
    assert(_node->len != 0);
    bool src_isdir = _node->str()[_node->len-1] == '/'; // found if item is a directory
    
    if(src_isdir && m_CopyMode == CopyToFile)
        return; // check if item is a directory and we're copying to a file - then just skip it, it's meaningless
    
    // compose file name - reverse lookup
    char itemname[__DARWIN_MAXPATHLEN];
    _node->str_with_pref(itemname);

    if(src_isdir)
        ProcessDirectory(itemname);
    else
        ProcessFile(itemname);
}

void FileOpMassCopy::ProcessDirectory(const char *_path)
{
    // TODO: directory attributes, time, permissions and xattrs
    assert(m_Destination[strlen(m_Destination)-1] == '/');
    assert(_path[strlen(_path)-1] == '/');
    
    const int maxdepth = FlexChainedStringsChunk::maxdepth; // 128 directories depth max
    struct stat stat_buffer;
    short slashpos[maxdepth];
    short absentpos[maxdepth];
    int ndirs = 0, nabsent = 0, pathlen = (int)strlen(_path);

    char fullpath[__DARWIN_MAXPATHLEN];
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
            switch (DoMessageBoxRetrySkipSkipAllCancel_CantCreateDir(fullpath, [m_Wnd window], errno))
            {
                case DialogResult::Retry: goto domkdir;
                case DialogResult::Skip:  return;
                case DialogResult::SkipAll: m_SkipAll = true; return;
                case DialogResult::Cancel: m_Cancel = true; return;
            }
        }
        fullpath[ slashpos[ absentpos[i] ] ] = '/';
    }
}

void FileOpMassCopy::ProcessFile(const char *_path)
{
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

opensource:
    if((sourcefd = open(sourcepath, O_RDONLY|O_SHLOCK)) == -1)
    {  // failed to open source file
        if(m_SkipAll) goto cleanup;
        switch(DoMessageBoxRetrySkipSkipallCancel_CannotAccessSourceFile(sourcepath, [m_Wnd window], errno))
        {
            case DialogResult::Retry:                       goto opensource;
            case DialogResult::Skip:                        goto cleanup;
            case DialogResult::SkipAll: m_SkipAll = true;   goto cleanup;
            case DialogResult::Cancel:  m_Cancel  = true;   goto cleanup;
        }
    }
    fcntl(sourcefd, F_NOCACHE, 1); // do not waste OS file cache with one-way data

statsource: // get information about source file
    if(fstat(sourcefd, &src_stat_buffer) == -1)
    {   // failed to stat source
        if(m_SkipAll) goto cleanup;        
        switch(DoMessageBoxRetrySkipSkipallCancel_CannotAccessSourceFile(sourcepath, [m_Wnd window], errno))
        {
            case DialogResult::Retry:                       goto statsource;
            case DialogResult::Skip:                        goto cleanup;
            case DialogResult::SkipAll: m_SkipAll = true;   goto cleanup;
            case DialogResult::Cancel:  m_Cancel  = true;   goto cleanup;
        }
    }

    // stat destination
    totaldestsize = src_stat_buffer.st_size;
    if(stat(destinationpath, &dst_stat_buffer) != -1)
    { // file already exist. what should we do now?
        if(m_SkipAll) goto cleanup;
        if(m_OverwriteAll) goto decoverwrite;
        if(m_AppendAll) goto decappend;
        switch(DoFileAlreadyExistSheetController([m_Wnd window], destinationpath, src_stat_buffer, dst_stat_buffer, &remember_choice))
        {
            case DialogResult::Overwrite:   if(remember_choice) m_OverwriteAll = true;  goto decoverwrite;
            case DialogResult::Append:      if(remember_choice) m_AppendAll = true;     goto decappend;
            case DialogResult::Skip:        if(remember_choice) m_SkipAll = true;       goto cleanup;
            case DialogResult::Cancel:      m_Cancel = true;                            goto cleanup;
        }
        
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
        switch(DoMessageBoxRetrySkipSkipallCancel_CannotOpenDestinationFile(destinationpath, [m_Wnd window], errno))
        {
            case DialogResult::Retry:                       goto opendest;
            case DialogResult::Skip:                        goto cleanup;
            case DialogResult::SkipAll: m_SkipAll = true;   goto cleanup;
            case DialogResult::Cancel:  m_Cancel  = true;   goto cleanup;
        }
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
        switch(DoMessageBoxRetrySkipSkipallCancel_WriteError(destinationpath, [m_Wnd window], errno))
        {
            case DialogResult::Retry:                       goto dotruncate;
            case DialogResult::Skip:                        goto cleanup;
            case DialogResult::SkipAll: m_SkipAll = true;   goto cleanup;
            case DialogResult::Cancel:  m_Cancel  = true;   goto cleanup;
        }
    }
    
dolseek: // find right position in destination file
    if(lseek(destinationfd, startwriteoff, SEEK_SET) == -1)
    {   // failed seek in a file. lolwhat?
        if(m_SkipAll) goto cleanup;
        switch(DoMessageBoxRetrySkipSkipallCancel_WriteError(destinationpath, [m_Wnd window], errno))
        {
            case DialogResult::Retry:                       goto dolseek;
            case DialogResult::Skip:                        goto cleanup;
            case DialogResult::SkipAll: m_SkipAll = true;   goto cleanup;
            case DialogResult::Cancel:  m_Cancel  = true;   goto cleanup;
        }
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
                                         switch(DoMessageBoxRetrySkipSkipallCancel_ReadError(sourcepathp, [m_Wnd window], errno))
                                         {
                                             case DialogResult::Retry:   goto doread;
                                             case DialogResult::Skip:    io_docancel = true; return;
                                             case DialogResult::SkipAll: io_docancel = true; m_SkipAll = true; return;
                                             case DialogResult::Cancel:  io_docancel = true; m_Cancel = true; return;
                                         }
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
                                         switch(DoMessageBoxRetrySkipSkipallCancel_WriteError(destinationpathp, [m_Wnd window], errno))
                                         {
                                             case DialogResult::Retry:   goto dowrite;
                                             case DialogResult::Skip:    io_docancel = true; return;
                                             case DialogResult::SkipAll: io_docancel = true; m_SkipAll = true; return;
                                             case DialogResult::Cancel:  io_docancel = true; m_Cancel = true; return;
                                         }
                                     }
                                     alreadywrote += nwrite;
                                     io_leftwrite -= nwrite;
                                 }
                                 io_totalwrote += alreadywrote;
                                 m_TotalCopied += alreadywrote;
                             });
        
        dispatch_group_wait(m_IOGroup, DISPATCH_TIME_FOREVER);
        if(io_docancel) break;
        if(io_totalwrote == src_stat_buffer.st_size) break;
        
        io_leftwrite = io_nread;
        std::swap(readbuf, writebuf); // swap our work buffers - read buffer become write buffer and vice versa

        // update statistics
        SetDone(double(m_TotalCopied) / double(m_SourceTotalBytes));
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
        struct timeval v[2];
        v[0].tv_sec = src_stat_buffer.st_atimespec.tv_sec; // last access time
        v[0].tv_usec = (__darwin_suseconds_t)(src_stat_buffer.st_atimespec.tv_nsec / 1000);
        v[1].tv_sec = src_stat_buffer.st_mtimespec.tv_sec; // last modification time
        v[1].tv_usec = (__darwin_suseconds_t)(src_stat_buffer.st_mtimespec.tv_nsec / 1000);
        futimes(destinationfd, v);
        // TODO: investigate why OSX set btime along with atime and mtime - it should not (?)
        // need to find a solid way to set btime
        // TODO: dig into "fsetattrlist" - maybe it's just that one
    }

cleanup:
    if(sourcefd != -1) close(sourcefd);
    if(destinationfd != -1) close(destinationfd);    
}
