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
#include "Common.h"

#define BUFFER_SIZE (512*1024) // 512kb
#define MIN_PREALLOC_SIZE (4096) // will try to preallocate files only if they are larger than 4k

static void SleepForSomeTime()
{
    usleep(50000); // 50 millisec
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
    ScanDestination();
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
    FlexChainedStringsChunk::FreeWithDescendants(&m_ScannedItems);
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
    {
        assert(0); // TODO: implement me later. ask user about folder/files choice if need
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
    // TODO: directory attributes

    assert(m_Destination[strlen(m_Destination)-1] == '/');
    assert(_path[strlen(_path)-1] == '/');
    
    const int maxdepth = 128; // 128 directories depth max
    struct stat stat_buffer;
    short slashpos[maxdepth];
    short absentpos[maxdepth];
    volatile int ret = 0;
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
        fullpath[slashpos[absentpos[i]]] = 0;
domkdir:
        int pret = mkdir(fullpath, 0777);
        fullpath[ slashpos[i] ] = '/';
        if(pret == -1)
        {
            MessageBoxRetryCancel(@"Cannot create directory:",
                                  [NSString stringWithUTF8String:strerror(errno)],
                                  [m_Wnd window],
                                  &ret);
            while(!ret) SleepForSomeTime();
            if(ret == NSAlertFirstButtonReturn) goto domkdir;
            if(ret == NSAlertSecondButtonReturn) return;
        }

//        tdone += ddone;
//        SetDone(tdone);
    }
    
    
}

void FileOpMassCopy::ProcessFile(const char *_path)
{
    volatile int ret = 0, *retp = &ret;
    bool remember_choice = false, *remember_choicep = &remember_choice;
    struct stat src_stat_buffer, dst_stat_buffer;
    char sourcepath[__DARWIN_MAXPATHLEN];
    char destinationpath[__DARWIN_MAXPATHLEN];
    int dstopenflags=0;
    int sourcefd=-1, destinationfd=-1;
    unsigned long startwriteoff = 0;
    unsigned long totaldestsize = 0;
    mode_t oldumask;
    fstore_t preallocstore = {F_ALLOCATECONTIG, F_PEOFPOSMODE, 0, 0};
    char *readbuf;
    char *writebuf;
    __block unsigned long leftwrite;
    __block unsigned long totalread;
    __block unsigned long totalwrote;
    __block bool docancel;
    FileAlreadyExistSheetController *fa;

    
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
    sourcefd = open(sourcepath, O_RDONLY|O_SHLOCK);
    if(sourcefd == -1)
    {
        // failed to open source file
        if(m_SkipAll)
            goto cleanup;

        MessageBoxRetrySkipSkipallCancel(@"Cannot access source file:",
                              [NSString stringWithUTF8String:strerror(errno)],
                              [m_Wnd window],
                              &ret);
        while(!ret) SleepForSomeTime();
        if(ret == NSAlertFirstButtonReturn) goto opensource;
        if(ret == NSAlertSecondButtonReturn) goto cleanup;
        if(ret == NSAlertThirdButtonReturn)   { m_SkipAll = true; goto cleanup; }
        if(ret == NSAlertThirdButtonReturn+1) { m_Cancel  = true; goto cleanup; }
    }
    fcntl(sourcefd, F_NOCACHE, 1);
    
statsource:
    memset(&src_stat_buffer, 0, sizeof(struct stat));
    if(fstat(sourcefd, &src_stat_buffer) == -1)
    {   // failed to stat source
        MessageBoxRetrySkipSkipallCancel(@"Cannot access source file:",
                              [NSString stringWithUTF8String:strerror(errno)],
                              [m_Wnd window],
                              &ret);
        while(!ret) SleepForSomeTime();
        if(ret == NSAlertFirstButtonReturn) goto statsource;
        if(ret == NSAlertSecondButtonReturn) goto cleanup;
        if(ret == NSAlertThirdButtonReturn)   { m_SkipAll = true; goto cleanup; }
        if(ret == NSAlertThirdButtonReturn+1) { m_Cancel  = true; goto cleanup; }
    }
    
    // stat destination
    startwriteoff = 0;
    totaldestsize = src_stat_buffer.st_size;
    memset(&dst_stat_buffer, 0, sizeof(struct stat));
    if(stat(destinationpath, &dst_stat_buffer) != -1)
    {
        // file already exist. what should we do now?
        if(m_SkipAll) goto cleanup;
        if(m_OverwriteAll) goto decoverwrite;
        if(m_AppendAll) goto decappend;
        
        ret = 0;
        
        fa = [[FileAlreadyExistSheetController alloc] init];
        [fa ShowSheet:[m_Wnd window]
             destpath:[NSString stringWithUTF8String:destinationpath]
              newsize:src_stat_buffer.st_size
              newtime:src_stat_buffer.st_mtimespec.tv_sec
              exisize:dst_stat_buffer.st_size
              exitime:dst_stat_buffer.st_mtimespec.tv_sec
              handler:^(int _ret, bool _remember){
                  *retp = _ret;
                  *remember_choicep = _remember;
              }];
        
        while(!ret) SleepForSomeTime();
        fa = nil;
        
        if(ret == DialogResult::Overwrite) // overwrite
        {
            if(remember_choice)
                m_OverwriteAll = true;
            goto decoverwrite;
        }
        if(ret == DialogResult::Append) // append
        {
            if(remember_choice)
                m_AppendAll = true;
            goto decappend;
        }
        if(ret == DialogResult::Skip) // skip
        {
            if(remember_choice)
                m_SkipAll = true;
            goto cleanup;
        }
        if(ret == DialogResult::Cancel) // cancel
        {
            m_Cancel = true;
            goto cleanup;
        }
        
// decisions about what to do with existing destination
decoverwrite:
        dstopenflags = O_WRONLY;
        goto decend;
decappend:
        dstopenflags = O_WRONLY;        
        totaldestsize += dst_stat_buffer.st_size;
        startwriteoff = dst_stat_buffer.st_size;        
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

        MessageBoxRetrySkipSkipallCancel(@"Cannot open destination file:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
        while(!ret) SleepForSomeTime();
        if(ret == NSAlertFirstButtonReturn) // retry
            goto opendest;
        if(ret == NSAlertSecondButtonReturn) // skip
            goto cleanup;
        if(ret == NSAlertThirdButtonReturn) // skip all
        {
            m_SkipAll = true;
            goto cleanup;
        }
        if(ret == NSAlertThirdButtonReturn+1) // cancel
        {
            m_Cancel = true;
            goto cleanup;
        }
    }
    
    // preallocate space for data since we dont want to trash our disk
    if(src_stat_buffer.st_size > MIN_PREALLOC_SIZE)
    {
        preallocstore.fst_length = src_stat_buffer.st_size;
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
        
        MessageBoxRetrySkipSkipallCancel(@"Write error:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
        while(!ret) SleepForSomeTime();
        if(ret == NSAlertFirstButtonReturn) // retry
            goto dotruncate;
        if(ret == NSAlertSecondButtonReturn) // skip
            goto cleanup;
        if(ret == NSAlertThirdButtonReturn) // skip all
        {
            m_SkipAll = true;
            goto cleanup;
        }
        if(ret == NSAlertThirdButtonReturn+1) // cancel
        {
            m_Cancel = true;
            goto cleanup;
        }
    }
    
dolseek: // find right position in destination file
    if(lseek(destinationfd, startwriteoff, SEEK_SET) == -1)
    {   // failed seek in a file. lolwhat?
        if(m_SkipAll) goto cleanup;
        
        MessageBoxRetrySkipSkipallCancel(@"Write error:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
        while(!ret) SleepForSomeTime();
        if(ret == NSAlertFirstButtonReturn) // retry
            goto dolseek;
        if(ret == NSAlertSecondButtonReturn) // skip
            goto cleanup;
        if(ret == NSAlertThirdButtonReturn) // skip all
        {
            m_SkipAll = true;
            goto cleanup;
        }
        if(ret == NSAlertThirdButtonReturn+1) // cancel
        {
            m_Cancel = true;
            goto cleanup;
        }
    }
    
    // environment setup
    readbuf = (char*)m_Buffer1;
    writebuf = (char*)m_Buffer2;
    leftwrite = 0;
    totalread = 0;
    totalwrote = 0;
    docancel = false;
    
    while(true)
    {
        __block ssize_t nread = 0;
        dispatch_group_async(m_IOGroup, m_ReadQueue, ^
                             {
                             doread:
                                 if(totalread < src_stat_buffer.st_size)
                                 {
                                     nread = read(sourcefd, readbuf, BUFFER_SIZE);
                                     if(nread == -1)
                                     {
                                         if(m_SkipAll) {docancel = true; return;}
                                         volatile int ret = 0;
                                         MessageBoxRetrySkipSkipallCancel(@"Read error:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
                                         while(!ret) SleepForSomeTime();
                                         if(ret==NSAlertFirstButtonReturn) goto doread; // retry
                                         if(ret==NSAlertSecondButtonReturn){docancel = true; return; }// skip
                                         if(ret==NSAlertThirdButtonReturn){docancel = true; m_SkipAll = true; return;} // skip all
                                         if(ret==NSAlertThirdButtonReturn+1){docancel = true; m_Cancel = true; return; } // cancel
                                         assert(0); // sanity check
                                     }
                                     totalread += nread;
                                 }
                             });
        
        dispatch_group_async(m_IOGroup, m_WriteQueue, ^
                             {
                                 unsigned long alreadywrote = 0;
                                 while(leftwrite > 0)
                                 {
                                 dowrite:
                                     ssize_t nwrite = write(destinationfd, writebuf + alreadywrote, leftwrite);
                                     if(nwrite == -1)
                                     {
                                         if(m_SkipAll) {docancel = true; return;}                                         
                                         volatile int ret = 0;
                                         MessageBoxRetryCancel(@"Write error:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
                                         while(!ret) SleepForSomeTime();
                                         if(ret==NSAlertFirstButtonReturn) goto dowrite; // retry
                                         if(ret==NSAlertSecondButtonReturn){docancel = true; return; }// skip
                                         if(ret==NSAlertThirdButtonReturn){docancel = true; m_SkipAll = true; return;} // skip all
                                         if(ret==NSAlertThirdButtonReturn+1){docancel = true; m_Cancel = true; return; } // cancel
                                         assert(0); // sanity check                                         
                                     }
                                     alreadywrote += nwrite;
                                     leftwrite -= nwrite;
                                 }
                                 totalwrote += alreadywrote;
                                 m_TotalCopied += alreadywrote;
                             });
        
        
        dispatch_group_wait(m_IOGroup, DISPATCH_TIME_FOREVER);
        if(docancel) break;
        if(totalwrote == src_stat_buffer.st_size) break;
        
        // swap our work buffers - read and write
        char *t = readbuf;
        readbuf = writebuf;
        writebuf = t;
        leftwrite = nread;
        
        // update statistics
        SetDone(double(m_TotalCopied) / double(m_SourceTotalBytes));
//        uint64_t currenttime = mach_absolute_time();
//        SetBytesPerSecond( double(totalwrote) / (double((currenttime - starttime)/1000000ul) / 1000.) );
    }
    

cleanup:
    if(sourcefd != -1) close(sourcefd);
    if(destinationfd != -1) close(destinationfd);    
}
