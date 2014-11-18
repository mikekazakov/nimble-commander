//
//  FSEventsDirUpdate.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 06.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <CoreFoundation/CoreFoundation.h>
#import <Cocoa/Cocoa.h>
#import "FSEventsDirUpdate.h"
#import "Common.h"

static const CFAbsoluteTime g_FSEventsLatency = 0.1;

// ask FS about real file path - case sensitive etc
// also we're getting rid of symlinks - it will be a real file
// return path with trailing slash
static bool GetRealPath(const char *_path_in, char *_path_out)
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

FSEventsDirUpdate::FSEventsDirUpdate()
{
}

FSEventsDirUpdate &FSEventsDirUpdate::Instance()
{
    static auto inst = new FSEventsDirUpdate; // never deleting object
    return *inst;
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
        const char *path = ((const char**)eventPaths)[i];
        
        if(w->path == path)
        {
            for(auto &h: w->handlers)
                h.second();
        }
        else
        {
            const FSEventStreamEventFlags flags = eventFlags[i];
            // check if watched directory was removed - need to fire on this case too
            if((flags == (kFSEventStreamEventFlagItemRenamed | kFSEventStreamEventFlagItemIsDir)) ||
               (flags == (kFSEventStreamEventFlagItemRemoved | kFSEventStreamEventFlagItemIsDir)) )
            {
                size_t path_len = strlen(path);

                if(path_len < w->path.length() && strncmp(w->path.c_str(), path, path_len) == 0)
                    for(auto &h: w->handlers)
                        h.second();
            }
        }
    }
}

unsigned long FSEventsDirUpdate::AddWatchPath(const char *_path, function<void()> _handler)
{
    // convert _path into canonical path of OS
    char dirpath[__DARWIN_MAXPATHLEN];
    if(!GetRealPath(_path, dirpath))
        return 0;
    
    // check if this path already presents in watched paths
    for(auto &i: m_Watches)
        if( i->path == dirpath )
        { // then just increase refcount and exit
            i->handlers.push_back(make_pair(m_LastTicket++, _handler));
            return i->handlers.back().first;
        }

    // create new watch stream
    auto w = make_unique<WatchData>();
    w->path = dirpath;
    w->handlers.emplace_back(m_LastTicket++, move(_handler));
    auto ticket = w->handlers.back().first;
    
    FSEventStreamContext context = {0, w.get(), NULL, NULL, NULL};
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
    
    m_Watches.emplace_back(move(w));
    
    return ticket;
}

bool FSEventsDirUpdate::RemoveWatchPathWithTicket(unsigned long _ticket)
{
    if(_ticket == 0)
        return false;
    
    for(auto i = m_Watches.begin(); i < m_Watches.end(); ++i)
    {
        WatchData *w = i->get();
        for(auto h = w->handlers.begin(); h < w->handlers.end(); ++h)
            if((*h).first == _ticket)
            {
                w->handlers.erase(h);
                if(w->handlers.empty())
                {
                    FSEventStreamStop(w->stream);
                    FSEventStreamUnscheduleFromRunLoop(w->stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
                    FSEventStreamInvalidate(w->stream);
                    FSEventStreamRelease(w->stream);
                    m_Watches.erase(i);
                }
                
                return true;
            }
    }
    
    return false;
}

void FSEventsDirUpdate::OnVolumeDidUnmount(const string &_on_path)
{
    // when some volume is removed from system we force every panel to reload it's data
    // TODO: this is a brute approach, need to build a more intelligent volume monitoring machinery later
    // it should monitor paths of removed volumes and fires notification only for appropriate watches
    for(auto &i: m_Watches)
        for(auto &h: (*i).handlers)
            h.second();
}
