// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FSEventsDirUpdate.h>
#include <DiskArbitration/DiskArbitration.h>
#include <CoreServices/CoreServices.h>
#include <sys/param.h>
#include <vector>
#include <unordered_map>
#include <Utility/StringExtras.h>
#include <Habanero/dispatch_cpp.h>
#include <Habanero/spinlock.h>

namespace nc::utility {

using namespace std;

static const CFAbsoluteTime g_FSEventsLatency = 0.05; // 50ms

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
        /**
         * canonical fs representation, should include a trailing slash.
         */
        string                                   path;     
        FSEventStreamRef                         stream;
        vector<pair<uint64_t, function<void()>>> handlers;
    };
    spinlock                            m_Lock;
    unordered_map<string, unique_ptr<WatchData>> m_Watches; // path -> watch data
    atomic_ulong                        m_LastTicket{ 1 }; // no #0 ticket, it'is an error code
    
    uint64_t    AddWatchPath(const char *_path, std::function<void()> _handler);
    void        RemoveWatchPathWithTicket(uint64_t _ticket);
    void        OnVolumeDidUnmount(const std::string &_on_path);
    
    static void DiskDisappeared(DADiskRef disk, void *context);
    static void FSEventsDirUpdateCallback(ConstFSEventStreamRef streamRef,
                                          void *userData,
                                          size_t numEvents,
                                          void *eventPaths,
                                          const FSEventStreamEventFlags eventFlags[],
                                          const FSEventStreamEventId eventIds[]);
    static FSEventStreamRef CreateEventStream(const string& path, void *context);
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


static bool ShouldFire(string_view _watched_path,
                       const size_t _num_events,
                       const char* _event_paths[],
                       const FSEventStreamEventFlags _event_flags[])
{
    for( size_t i = 0; i < _num_events; i++ ) {
        const auto flags = _event_flags[i];
        if( flags & kFSEventStreamEventFlagRootChanged ) {
            return true;
        }
        else {
            // this checking should be blazing fast, since we can get A LOT of events here
            // (from all sub-dirs) and we need only events from current-level directory
            const auto path = string_view{_event_paths[i]};
            if( path == _watched_path )
                return true;
        }
    }
    return false;
}

void FSEventsDirUpdate::Impl::
    FSEventsDirUpdateCallback([[maybe_unused]] ConstFSEventStreamRef _stream_ref,
                              void *_user_data,
                              size_t _num,
                              void *_paths,
                              const FSEventStreamEventFlags _flags[],
                              [[maybe_unused]] const FSEventStreamEventId _ids[])
{
    const WatchData &watch = *(const WatchData *)_user_data;
    if( ShouldFire(watch.path, _num, (const char**)_paths, _flags) ) {
        for( auto &h: watch.handlers )
            h.second();
    }
}

FSEventStreamRef FSEventsDirUpdate::Impl::CreateEventStream(const string& path, void *context_ptr)
{
    const auto cf_path = CFStringCreateWithUTF8StdString( path );
    if( !cf_path )
        return 0;
    
    CFArrayRef pathsToWatch = CFArrayCreate(0, (const void**)&cf_path, 1, nullptr);
    FSEventStreamRef stream = nullptr;
    auto create_stream = [&]{        
        const auto flags = kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot;
        auto context = FSEventStreamContext{0, context_ptr, nullptr, nullptr, nullptr};        
        stream = FSEventStreamCreate(nullptr,
                                     &FSEventsDirUpdate::Impl::FSEventsDirUpdateCallback,
                                     &context,
                                     pathsToWatch,
                                     kFSEventStreamEventIdSinceNow,
                                     g_FSEventsLatency,
                                     flags);
    };
    
    if( dispatch_is_main_queue() )
        create_stream();
    else
        dispatch_sync(dispatch_get_main_queue(), create_stream);    
    
    CFRelease(pathsToWatch);
    CFRelease(cf_path);
    
    return stream;
}

static void StartStream(FSEventStreamRef _stream)
{
    assert(_stream != nullptr);
    
    auto schedule_and_run = [=]{
        FSEventStreamScheduleWithRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        FSEventStreamStart(_stream);
    };
    
    if( dispatch_is_main_queue() )
        schedule_and_run();
    else
        dispatch_to_main_queue( schedule_and_run );
}

static void StopStream(FSEventStreamRef _stream)
{
    assert(_stream != nullptr);
    dispatch_assert_main_queue();
    FSEventStreamStop(_stream);
    FSEventStreamUnscheduleFromRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamInvalidate(_stream);
    FSEventStreamRelease(_stream);
}

uint64_t FSEventsDirUpdate::AddWatchPath(const char *_path, function<void()> _handler)
{
    return me->AddWatchPath( _path, move(_handler) );
}

uint64_t FSEventsDirUpdate::Impl::AddWatchPath(const char *_path, function<void()> _handler)
{
    if( !_path || !_handler )
        return no_ticket;
    
    // convert _path into canonical path of OS
    const auto dir_path = GetRealPath(_path);
    if( dir_path.empty() )
        return no_ticket;
    
    // monotonically increase current ticket to get a next unique one
    const auto ticket = m_LastTicket++;    
    
    auto lock = lock_guard{m_Lock};
    
    // check if this path already presents in watched paths
    if( auto it = m_Watches.find(dir_path); it != m_Watches.end() ) {
        it->second->handlers.emplace_back(ticket, move(_handler));
        return ticket;
    }
    
    // create a new watch stream            
    auto w = make_unique<WatchData>();
    w->path = dir_path;    
    w->handlers.emplace_back(ticket, move(_handler));
    w->stream = CreateEventStream(dir_path, w.get());
    if( w->stream == nullptr )
        return no_ticket;
    StartStream(w->stream);    
    m_Watches.emplace( make_pair(dir_path, move(w)) );

    return ticket;
}

void FSEventsDirUpdate::RemoveWatchPathWithTicket(uint64_t _ticket)
{
    me->RemoveWatchPathWithTicket(_ticket);
}

template <class Container, class Iterator>
static inline void unordered_erase( Container &c, Iterator i )
{
    // can do this since erase() requires a valid iterator => thus c is not empty.
    auto last = prev(end(c));
    
    if( last != i )
        iter_swap(i, last);
    
    c.erase(last);
}

void FSEventsDirUpdate::Impl::RemoveWatchPathWithTicket(uint64_t _ticket)
{
    if( _ticket == no_ticket )
        return;
    
    if( !dispatch_is_main_queue() ) {
        dispatch_to_main_queue( [=]{ RemoveWatchPathWithTicket(_ticket); } );
        return;
    }
    
    auto lock = lock_guard{m_Lock};
    
    for( auto i = begin(m_Watches), e = end(m_Watches); i != e; ++i ) {
        auto &watch = *(i->second);
        for( auto h = begin(watch.handlers), he = end(watch.handlers); h != he; ++h )
            if( h->first == _ticket ) {
                unordered_erase(watch.handlers, h);
                if( watch.handlers.empty() ) {
                    StopStream(watch.stream);
                    m_Watches.erase(i);
                }
                return;
            }
    }    
}

void FSEventsDirUpdate::OnVolumeDidUnmount(const string &_on_path)
{
    me->OnVolumeDidUnmount(_on_path);    
}

static bool StartsWith( string_view string, string_view prefix )
{
    return string.size() >= prefix.size() && string.compare(0, prefix.size(), prefix) == 0;
}

void FSEventsDirUpdate::Impl::OnVolumeDidUnmount(const string &_on_path)
{
    // when a volume is removed from the system we force every relevant panel to reload its data
    dispatch_assert_main_queue();    
    for( auto &i: m_Watches ) {
        if(  StartsWith(i.second->path, _on_path) ) {
            for( auto &h: i.second->handlers )
                h.second();
        }
    }
}

}
