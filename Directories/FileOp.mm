//
//  FileOp.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 26.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "FileOp.h"
#include <string.h>
#include <sys/types.h>
#include <sys/dirent.h>
#include <sys/stat.h>
#include <fcntl.h>
//#include <osfmk/kern/clock.h>
#include <mach/mach_time.h>

#include "MessageBox.h"
#include "MainWindowController.h"

//#define BUFFER_SIZE (64*1024)
#define BUFFER_SIZE (512*1024) // 512kb


// TODO: consider using dispatch_semaphore instead of nanosleep

// TODO: handle ~/... paths somehow


static void SleepForSomeTime()
{
    usleep(50000); // 50 millisec
}

AbstractFileJob::AbstractFileJob():
    m_Done(0.),
    m_ReadyToPurge(false),
    m_BytesPerSecond(0.)
{
}

AbstractFileJob::~AbstractFileJob()
{
}

double AbstractFileJob::BytesPerSecond() const
{
    return m_BytesPerSecond;
}

double AbstractFileJob::Done() const
{
    return m_Done;
}

bool AbstractFileJob::IsReadyToPurge() const
{
    return m_ReadyToPurge;
}

void AbstractFileJob::SetDone(double _val)
{
    m_Done = _val;
}

void AbstractFileJob::SetBytesPerSecond(double _val)
{
    m_BytesPerSecond = _val;
}

void AbstractFileJob::SetReadyToPurge()
{
    m_ReadyToPurge = true;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

FileCopy::FileCopy():
    m_SrcFD(-1),
    m_DestFD(-1),
    m_Buffer1(0),
    m_Buffer2(0),
    m_Wnd(0)
{
}

FileCopy::~FileCopy(){ /* all cleanup task should be done in DoCleanup() */ }

void FileCopy::InitOpData(const char *_src, const char *_dest, MainWindowController *_wnd)
{
    m_Wnd = _wnd;
    strcpy(m_SrcPath, _src);
//    strcat(m_SrcPath, "!");
//    if(strchr(_dest, '/'))
    if(_dest[0] == '/')
    {
        // assume that _dest is a full path
        strcpy(m_DestPath, _dest);
    }
    else
    {
        // assume that _dest is local path, need to combine it with path from _src
        strcpy(m_DestPath, _src); // assume that _src is a full path and is not corrupted
        strcpy(strrchr(m_DestPath, '/') + 1, _dest);
    }
}

void FileCopy::Run()
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

void FileCopy::DoCleanup()
{
    if(m_SrcFD != -1) close(m_SrcFD);
    if(m_DestFD != -1) close(m_DestFD);
    if(m_Buffer1) free(m_Buffer1);
    if(m_Buffer2) free(m_Buffer2);
}

void FileCopy::DoRun()
{
    volatile int ret = 0;
    struct stat src_stat_buffer, dst_stat_buffer;

opensource:
    m_SrcFD = open(m_SrcPath, O_RDONLY|O_SHLOCK);
    if(m_SrcFD == -1)
    {   // failed to open source file
        MessageBoxRetryCancel(@"Cannot access source file:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
        while(!ret) SleepForSomeTime();
        if(ret == NSAlertFirstButtonReturn) goto opensource;
        if(ret == NSAlertSecondButtonReturn) return;
    }
    fcntl(m_SrcFD, F_NOCACHE, 1);
    
statsource:
    memset(&src_stat_buffer, 0, sizeof(struct stat));
    if(fstat(m_SrcFD, &src_stat_buffer) == -1)
    {   // failed to stat source
        MessageBoxRetryCancel(@"Cannot access source file:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
        while(!ret) SleepForSomeTime();
        if(ret == NSAlertFirstButtonReturn) goto statsource;
        if(ret == NSAlertSecondButtonReturn) return;
    }

    // stat destination
    int dstflags=0;
    unsigned long startwriteoff = 0;
    unsigned long totaldestsize = src_stat_buffer.st_size;
    memset(&dst_stat_buffer, 0, sizeof(struct stat));
    if(stat(m_DestPath, &dst_stat_buffer) != -1)
    {
        // file already exist. as for action - override/append/cancel
        MessageBoxOverwriteAppendCancel(@"File already exist.", @"What to do?", [m_Wnd window], &ret);
        while(!ret) SleepForSomeTime();
        if(ret == NSAlertFirstButtonReturn) dstflags = O_WRONLY;
        if(ret == NSAlertSecondButtonReturn)
        {
            dstflags = O_WRONLY;
            totaldestsize += dst_stat_buffer.st_size;
            startwriteoff = dst_stat_buffer.st_size;
        }
        if(ret == NSAlertThirdButtonReturn) return;
    }
    else
    { // no dest file - just create it
        dstflags = O_WRONLY|O_CREAT;
    }
    
opendest:
    mode_t oldumask = umask(0); // we want to copy src permissions
    m_DestFD = open(m_DestPath, dstflags, src_stat_buffer.st_mode);
    umask(oldumask);

    if(m_DestFD == -1)
    {   // failed to open destination file
        MessageBoxRetryCancel(@"Cannot open destination file:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
        while(!ret) SleepForSomeTime();
        if(ret == NSAlertFirstButtonReturn) goto opendest;
        if(ret == NSAlertSecondButtonReturn) return;
    }

    // preallocate space for data since we dont want to trash our disk
    fstore_t preallocstore = {F_ALLOCATECONTIG, F_PEOFPOSMODE, 0, src_stat_buffer.st_size};
    if(fcntl(m_DestFD, F_PREALLOCATE, &preallocstore) == -1)
    {
        preallocstore.fst_flags = F_ALLOCATEALL;
        fcntl(m_DestFD, F_PREALLOCATE, &preallocstore);
    }
    fcntl(m_DestFD, F_NOCACHE, 1); // caching is meaningless here?
    
dotruncate:
    if(ftruncate(m_DestFD, totaldestsize) == -1)
    {   // failed to set dest file size
        MessageBoxRetryCancel(@"Write error:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
        while(!ret) SleepForSomeTime();
        if(ret == NSAlertFirstButtonReturn) goto dotruncate;
        if(ret == NSAlertSecondButtonReturn) return;
    }

dolseek:
    if(lseek(m_DestFD, startwriteoff, SEEK_SET) == -1)
    {   // failed seek in a file. lolwhat?
        MessageBoxRetryCancel(@"Write error:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
        while(!ret) SleepForSomeTime();
        if(ret == NSAlertFirstButtonReturn) goto dolseek;
        if(ret == NSAlertSecondButtonReturn) return;
    }

    dispatch_queue_t readqueue = dispatch_queue_create(0, 0);
    dispatch_queue_t writequeue = dispatch_queue_create(0, 0);
    dispatch_group_t iogroup = dispatch_group_create();
    
    m_Buffer1 = malloc(BUFFER_SIZE);
    m_Buffer2 = malloc(BUFFER_SIZE);
    
    char *readbuf = (char*)m_Buffer1;
    char *writebuf = (char*)m_Buffer2;
    __block unsigned long leftwrite = 0;
    __block unsigned long totalread = 0;
    __block unsigned long totalwrote = 0;
    __block bool docancel = false;
    uint64_t starttime = mach_absolute_time(); // in nanoseconds
    
    // TODO: UB when input and output streams fucks up at once - fixme
    
    while(true)
    {
        __block ssize_t nread = 0;
        dispatch_group_async(iogroup, readqueue, ^
        {
doread:
            if(totalread < src_stat_buffer.st_size)
            {
                nread = read(m_SrcFD, readbuf, BUFFER_SIZE);
                if(nread == -1)
                {
                    volatile int ret = 0;
                    MessageBoxRetryCancel(@"Read error:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
                    while(!ret) SleepForSomeTime();
                    if(ret == NSAlertFirstButtonReturn) goto doread;
                    if(ret == NSAlertSecondButtonReturn) { docancel = true; return; }
                }
                totalread += nread;
            }
        });
        
        dispatch_group_async(iogroup, writequeue, ^
        {
            unsigned long alreadywrote = 0;
            while(leftwrite > 0)
            {
dowrite:
                ssize_t nwrite = write(m_DestFD, writebuf + alreadywrote, leftwrite);
                if(nwrite == -1)
                {
                    volatile int ret = 0;                    
                    MessageBoxRetryCancel(@"Write error:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
                    while(!ret) SleepForSomeTime();
                    if(ret == NSAlertFirstButtonReturn) goto dowrite;
                    if(ret == NSAlertSecondButtonReturn) { docancel = true; return; }
                }
                alreadywrote += nwrite;
                leftwrite -= nwrite;
            }
            totalwrote += alreadywrote;
        });
        
        dispatch_group_wait(iogroup, DISPATCH_TIME_FOREVER);
        if(docancel) break;
        if(totalwrote == src_stat_buffer.st_size) break;
        
        // swap our work buffers - read and write
        char *t = readbuf;
        readbuf = writebuf;
        writebuf = t;
        leftwrite = nread;

        // update statistics
        SetDone(double(totalwrote) / double(src_stat_buffer.st_size));
        uint64_t currenttime = mach_absolute_time();
        SetBytesPerSecond( double(totalwrote) / (double((currenttime - starttime)/1000000ul) / 1000.) );
    }

    SetDone(1.);
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DirectoryCreate::DirectoryCreate()
{
}

DirectoryCreate::~DirectoryCreate()
{
}

void DirectoryCreate::InitOpData(const char *_name, const char *_in_dir, MainWindowController *_wnd)
{
    m_Wnd = _wnd;
//    if(strchr(_name, '/'))
    if(_name[0] == '/')
    {
        // assume that _name is a full path
        strcpy(m_Name, _name);
        
//        strcpy(m_PathPriorTo, _name);
//        *(strrchr(m_PathPriorTo, '/')+1) = 0;
    }
    else
    {
        // assume that _name is local path, need to combine it with path from _in_dir
        strcpy(m_Name, _in_dir); // assume that _in_dir is a full path and is not corrupted
        if( m_Name[strlen(m_Name)-1] != '/' ) strcat(m_Name, "/");
//        strcpy(m_PathPriorTo, m_Name);
        strcat(m_Name, _name);
    }
}

void DirectoryCreate::Run()
{
    dispatch_queue_t queue = dispatch_queue_create(0, 0);
    dispatch_async(queue,^
                   {
                       DoRun();
                       usleep(300000); // give a user 0.3sec to see that we're done
                       SetReadyToPurge();
                       
                   });    
}

void DirectoryCreate::DoRun()
{
    const int maxdepth = 128; // 128 directories depth max
    struct stat stat_buffer;
    short slashpos[maxdepth];
    short absentpos[maxdepth];
    volatile int ret = 0;
    int ndirs = 0, nabsent = 0, pathlen = (int)strlen(m_Name);
    double tdone=0, ddone=0;
    
    for(int i = pathlen-1; i > 0; --i )
        if(m_Name[i] == '/')
            slashpos[ndirs++] = i;
    
    // find absent directories in full path
    for(int i = 0; i < ndirs; ++i)
    {
        m_Name[ slashpos[i] ] = 0;
        if(stat(m_Name, &stat_buffer) == -1)
            absentpos[nabsent++] = i;
        m_Name[ slashpos[i] ] = '/';
    }
    
    ddone = 1. / (nabsent+1);
    
    // mkdir absent directories prior to ending dir
    for(int i = nabsent-1; i >= 0; --i)
    {
        m_Name[slashpos[absentpos[i]]] = 0;
domkdir1:
        if(mkdir(m_Name, 0777) == -1)
        {
            MessageBoxRetryCancel(@"Cannot create directory:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
            while(!ret) SleepForSomeTime();
            if(ret == NSAlertFirstButtonReturn) goto domkdir1;
            if(ret == NSAlertSecondButtonReturn) return;
        }
        m_Name[ slashpos[i] ] = '/';
        tdone += ddone;
        SetDone(tdone);
    }
    
domkdir2:
    if(mkdir(m_Name, 0777) == -1)
    {
        MessageBoxRetryCancel(@"Cannot create directory:", [NSString stringWithUTF8String:strerror(errno)], [m_Wnd window], &ret);
        while(!ret) SleepForSomeTime();
        if(ret == NSAlertFirstButtonReturn) goto domkdir2;
        if(ret == NSAlertSecondButtonReturn) return;
    }

    SetDone(1.);
}


