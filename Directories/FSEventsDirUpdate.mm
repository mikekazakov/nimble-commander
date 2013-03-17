//
//  FSEventsDirUpdate.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 06.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
//#include <AppKit.framework/Headers/NSApplication.h>
#import <Cocoa/Cocoa.h>
#include "FSEventsDirUpdate.h"
#include "AppDelegate.h"

static FSEventsDirUpdate *g_Inst = 0;

// ask FS about real file path - case sensitive etc
// also we're getting rid of symlinks - it will be a real file
// return path with trailing slash
bool GetRealPath(const char *_path_in, char *_path_out)
{
    int tfd = open(_path_in, O_RDONLY);
    if(tfd == -1)
        return false;
    int ret = fcntl(tfd, F_GETPATH, _path_out);
    close(tfd);
    if(ret == -1)
        return false;
    if( _path_out[strlen(_path_out)-1] != '/' )
        strcat(_path_out, "/");
    return true;
}

FSEventsDirUpdate::FSEventsDirUpdate():
    m_LastTicket(1) // no tickets #0, since it'is an error code 
{
}

FSEventsDirUpdate *FSEventsDirUpdate::Inst()
{
    if(!g_Inst) g_Inst = new FSEventsDirUpdate(); // never deleting object
    return g_Inst;
}

void FSEventsDirUpdate::FSEventsDirUpdateCallback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[])
{
    Inst()->UpdateCallback(streamRef, userData, numEvents, eventPaths, eventFlags, eventIds);
}

void FSEventsDirUpdate::UpdateCallback(ConstFSEventStreamRef streamRef,
                    void *userData,
                    size_t numEvents,
                    void *eventPaths,
                    const FSEventStreamEventFlags eventFlags[],
                    const FSEventStreamEventId eventIds[])
{
    const WatchData *w = (const WatchData *) userData;
    
    for(size_t i=0; i < numEvents; i++)
    {
        // this checking should be blazing fast, since we can get A LOT of events here (from all sub-dirs)
        // and we need only events from current-level directory
        // TODO: check this performance

        const char *path = ((const char**)eventPaths)[i];

        if(w->path == path)
            [(AppDelegate*)[NSApp delegate] FireDirectoryChanged:path ticket:w->ticket];
    }
}

unsigned long  FSEventsDirUpdate::AddWatchPath(const char *_path)
{
    // convert _path into canonical path of OS
    char dirpath[__DARWIN_MAXPATHLEN];
    if(!GetRealPath(_path, dirpath))
        return 0;
    
    // check if this path already presents in watched paths
    for(auto i = m_Watches.begin(); i < m_Watches.end(); ++i)
    {
        if( (*i)->path == dirpath )
        { // then just increase refcount and exit
            (*i)->refcount++;
            return (*i)->ticket;
        }
    }
    
    // create new watch stream
    WatchData *w = new WatchData;
    w->path = dirpath;
    w->ticket = m_LastTicket++;
    w->refcount = 1;
    w->running = true;
    
    FSEventStreamContext context = {0, w, NULL, NULL, NULL};
    NSTimeInterval latency = 0.2;
    CFStringRef path = CFStringCreateWithBytes(0, (const UInt8*)_path, strlen(_path), kCFStringEncodingUTF8, false);

    void *ar[1] = {(void*)path};
    CFArrayRef pathsToWatch = CFArrayCreate(0, (const void**)ar, 1, &kCFTypeArrayCallBacks);
        
    FSEventStreamRef stream = FSEventStreamCreate(NULL,
                                 &FSEventsDirUpdate::FSEventsDirUpdateCallback,
                                 &context,
                                 pathsToWatch,
                                 kFSEventStreamEventIdSinceNow,
                                 (CFAbsoluteTime) latency,
                                 0
                                 );
    CFRelease(pathsToWatch);
    CFRelease(path);
    
    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);
    
    w->stream = stream;
    
    m_Watches.push_back(w);
    
    return w->ticket;
}

bool FSEventsDirUpdate::RemoveWatchPath(const char *_path)
{
    char dirpath[__DARWIN_MAXPATHLEN];
    if(!GetRealPath(_path, dirpath))
        return false;

    for(auto i = m_Watches.begin(); i < m_Watches.end(); ++i)
        if((*i)->path == dirpath)
        {
            WatchData *w = *i;
            w->refcount--;
            if(w->refcount == 0)
            {
                if(w->running)
                    FSEventStreamStop(w->stream);
                FSEventStreamScheduleWithRunLoop(w->stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
                FSEventStreamInvalidate(w->stream);
                FSEventStreamRelease(w->stream);
                delete w;
                m_Watches.erase(i);
            }
            return true;
        }

    return false;
}

bool FSEventsDirUpdate::RemoveWatchPathWithTicket(unsigned long _ticket)
{
    if(_ticket == 0)
        return false;
    
    for(auto i = m_Watches.begin(); i < m_Watches.end(); ++i)
        if((*i)->ticket == _ticket)
        {
            WatchData *w = *i;
            w->refcount--;
            if(w->refcount == 0)
            {
                if(w->running)
                    FSEventStreamStop(w->stream);
                FSEventStreamScheduleWithRunLoop(w->stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
                FSEventStreamInvalidate(w->stream);
                FSEventStreamRelease(w->stream);
                delete w;
                m_Watches.erase(i);
            }
            return true;
        }
    
    return false;
}
