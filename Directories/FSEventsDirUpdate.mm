//
//  FSEventsDirUpdate.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 06.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <CoreFoundation/CoreFoundation.h>
#import <DiskArbitration/DiskArbitration.h>
#import <Cocoa/Cocoa.h>
#import "FSEventsDirUpdate.h"
#import "AppDelegate.h"
#import "Common.h"

static const CFAbsoluteTime g_FSEventsLatency = 0.1;
static FSEventsDirUpdate *g_Inst = 0;

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
    for(auto i: m_Watches)
        if( i->path == dirpath )
        { // then just increase refcount and exit
            i->refcount++;
            return i->ticket;
        }

    // create new watch stream
    WatchData *w = new WatchData;
    w->path = dirpath;
    w->ticket = m_LastTicket++;
    w->refcount = 1;
    char volume[MAXPATHLEN] = {0};
    GetFileSystemRootFromPath(dirpath, volume);
    w->volume_path = volume;
    
    FSEventStreamContext context = {0, w, NULL, NULL, NULL};
    CFStringRef path = CFStringCreateWithBytes(0, (const UInt8*)_path, strlen(_path), kCFStringEncodingUTF8, false);

    void *ar[1] = {(void*)path};
    CFArrayRef pathsToWatch = CFArrayCreate(0, (const void**)ar, 1, &kCFTypeArrayCallBacks);
        
    FSEventStreamRef stream = FSEventStreamCreate(NULL,
                                 &FSEventsDirUpdate::FSEventsDirUpdateCallback,
                                 &context,
                                 pathsToWatch,
                                 kFSEventStreamEventIdSinceNow,
                                 g_FSEventsLatency,
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
                FSEventStreamStop(w->stream);
                FSEventStreamUnscheduleFromRunLoop(w->stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
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
                FSEventStreamStop(w->stream);
                FSEventStreamUnscheduleFromRunLoop(w->stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
                FSEventStreamInvalidate(w->stream);
                FSEventStreamRelease(w->stream);
                delete w;
                m_Watches.erase(i);
            }
            return true;
        }
    
    return false;
}

void FSEventsDirUpdate::DiskDisappeared(DADiskRef disk, void *context)
{
    // when some volume is removed from system we force every panel to reload it's data
    // TODO: this is a brute approach, need to build a more intelligent volume monitoring machinery later
    // it should monitor paths of removed volumes and fires notification only for appropriate watches
    FSEventsDirUpdate *me = Inst();
    for(auto i: me->m_Watches)
        [(AppDelegate*)[NSApp delegate] FireDirectoryChanged:i->path.c_str() ticket:i->ticket];
}

void FSEventsDirUpdate::RunDiskArbitration()
{
    DASessionRef session = DASessionCreate(kCFAllocatorDefault);
    DARegisterDiskDisappearedCallback(session, NULL, FSEventsDirUpdate::DiskDisappeared, NULL);
    DASessionScheduleWithRunLoop(session, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
}