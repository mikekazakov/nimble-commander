// Copyright (C) 2013-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <DiskArbitration/DiskArbitration.h>
#include <CoreServices/CoreServices.h>
#include <sys/param.h>
#include <vector>

#include <Utility/FSEventsDirUpdate.h>
#include <Habanero/dispatch_cpp.h>
#include <Habanero/spinlock.h>

using namespace std;

static const CFAbsoluteTime g_FSEventsLatency = 0.1;

// ask FS about real file path - case sensitive etc
// also we're getting rid of symlinks - it will be a real file
// return path with trailing slash
static string GetRealPath(const char *_path_in)
{
    int tfd = open(_path_in, O_RDONLY);
    if(tfd == -1)
        return {};
    char path_buf[MAXPATHLEN];
    int ret = fcntl(tfd, F_GETPATH, path_buf);
    close(tfd);
    if(ret == -1)
        return {};
    
    string path_out(path_buf);
    if(!path_out.empty() && path_out.back() != '/')
        path_out += '/';
    
    return path_out;
}

struct FSEventsDirUpdate::Impl
{
    struct WatchData
    {
        string                                   path;     // canonical fs representation, should include trailing slash
        FSEventStreamRef                         stream;
        vector<pair<uint64_t, function<void()>>> handlers;
    };
    spinlock                            m_Lock;
    vector<unique_ptr<WatchData>>       m_Watches;
    atomic_ulong                        m_LastTicket{ 1 }; // no tickets #0, since it'is an error code
    
    uint64_t    AddWatchPath(const char *_path, std::function<void()> _handler);
    bool        RemoveWatchPathWithTicket(uint64_t _ticket);
    void        OnVolumeDidUnmount(const std::string &_on_path);
    
    static void DiskDisappeared(DADiskRef disk, void *context);
    static void FSEventsDirUpdateCallback(ConstFSEventStreamRef streamRef,
                                          void *userData,
                                          size_t numEvents,
                                          void *eventPaths,
                                          const FSEventStreamEventFlags eventFlags[],
                                          const FSEventStreamEventId eventIds[]);
    
    
};

FSEventsDirUpdate::FSEventsDirUpdate():
    me(make_unique<Impl>())
{
}

FSEventsDirUpdate &FSEventsDirUpdate::Instance()
{
    static auto inst = new FSEventsDirUpdate; // never deleting object
    return *inst;
}

void FSEventsDirUpdate::Impl::FSEventsDirUpdateCallback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[])
{
    const WatchData &w = *(const WatchData *) userData;
    
    for(size_t i=0; i < numEvents; i++) {
        // this checking should be blazing fast, since we can get A LOT of events here (from all sub-dirs)
        // and we need only events from current-level directory
        const char *path = ((const char**)eventPaths)[i];
        size_t path_len = strlen(path);
        
        if( w.path.length() == path_len && w.path == path ) {
            for(auto &h: w.handlers)
                h.second();
        }
        else {
            const FSEventStreamEventFlags flags = eventFlags[i];
            // check if watched directory was removed - need to fire on this case too
            if((flags == (kFSEventStreamEventFlagItemRenamed | kFSEventStreamEventFlagItemIsDir)) ||
               (flags == (kFSEventStreamEventFlagItemRemoved | kFSEventStreamEventFlagItemIsDir)) ) {
                if(path_len < w.path.length() && strncmp(w.path.c_str(), path, path_len) == 0)
                    for(auto &h: w.handlers)
                        h.second();
            }
        }
    }
}

uint64_t FSEventsDirUpdate::AddWatchPath(const char *_path, function<void()> _handler)
{ return me->AddWatchPath( _path, move(_handler) ); }
uint64_t FSEventsDirUpdate::Impl::AddWatchPath(const char *_path, function<void()> _handler)
{
    if( !_path || !_handler )
        return 0;
    
    // convert _path into canonical path of OS
    string dirpath = GetRealPath(_path);
    if(dirpath.empty())
        return 0;
    
    // check if this path already presents in watched paths
    for(auto &i: m_Watches)
        if( i->path == dirpath ) { // then just add handler and exit
            i->handlers.emplace_back(m_LastTicket++, move(_handler));
            return i->handlers.back().first;
        }

    // create new watch stream
    auto w = make_unique<WatchData>();
    w->path = dirpath;
    w->handlers.emplace_back(m_LastTicket++, move(_handler));
    auto ticket = w->handlers.back().first;
    
    FSEventStreamContext context = {0, w.get(), NULL, NULL, NULL};
    CFStringRef path = CFStringCreateWithBytes(0, (const UInt8*)dirpath.c_str(), dirpath.length(), kCFStringEncodingUTF8, false);
    if(!path)
        return 0;
    
    CFArrayRef pathsToWatch = CFArrayCreate(0, (const void**)&path, 1, NULL);
    FSEventStreamRef stream = nullptr;
    auto create_stream = [&]{
        stream = FSEventStreamCreate(NULL,
                                     &FSEventsDirUpdate::Impl::FSEventsDirUpdateCallback,
                                     &context,
                                     pathsToWatch,
                                     kFSEventStreamEventIdSinceNow,
                                     g_FSEventsLatency,
                                     0
                                     );
    };
    
    if( dispatch_is_main_queue() )
        create_stream();
    else
        dispatch_sync(dispatch_get_main_queue(), create_stream);
    
    CFRelease(pathsToWatch);
    CFRelease(path);

    w->stream = stream;
    
    LOCK_GUARD(m_Lock) {
        m_Watches.emplace_back( move(w) );
    }
    
    auto schedule_and_run = [=]{
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        FSEventStreamStart(stream);
    };
    
    if( dispatch_is_main_queue() ) schedule_and_run();
    else   dispatch_to_main_queue( schedule_and_run );
    
    return ticket;
}

bool FSEventsDirUpdate::RemoveWatchPathWithTicket(uint64_t _ticket)
{ return me->RemoveWatchPathWithTicket(_ticket); }
bool FSEventsDirUpdate::Impl::RemoveWatchPathWithTicket(uint64_t _ticket)
{
    if(_ticket == 0)
        return false;
    
    if( !dispatch_is_main_queue() ) {
        dispatch_to_main_queue( [=]{ RemoveWatchPathWithTicket(_ticket); } );
        return true;
    }
    
    LOCK_GUARD(m_Lock)
        for(auto i = begin(m_Watches), e = end(m_Watches); i != e ; ++i) {
            WatchData *w = i->get();
            for(auto h = w->handlers.begin(); h < w->handlers.end(); ++h)
                if(h->first == _ticket) {
                    w->handlers.erase(h);
                    if(w->handlers.empty()) {
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
{ me->OnVolumeDidUnmount(_on_path); }
void FSEventsDirUpdate::Impl::OnVolumeDidUnmount(const string &_on_path)
{
    // when some volume is removed from system we force every panel to reload it's data
    // TODO: this is a brute approach, need to build a more intelligent volume monitoring machinery later
    // it should monitor paths of removed volumes and fires notification only for appropriate watches
    for(auto &i: m_Watches)
        for(auto &h: (*i).handlers)
            h.second();
}
