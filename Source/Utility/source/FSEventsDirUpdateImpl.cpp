// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FSEventsDirUpdateImpl.h"
#include <sys/param.h>
#include <vector>
#include <unordered_map>
#include <Utility/StringExtras.h>
#include <Utility/Log.h>
#include <Base/dispatch_cpp.h>
#include <Base/spinlock.h>
#include <Base/StackAllocator.h>
#include <fmt/ranges.h>
#include <span>

namespace nc::utility {

static const CFAbsoluteTime g_FSEventsLatency = 0.05; // 50ms

// ask FS about real file path - case sensitive etc
// also we're getting rid of symlinks - it will be a real file
// return path with trailing slash
static std::string GetRealPath(std::string_view _path_in)
{
    StackAllocator alloc;
    const std::pmr::string path_in(_path_in, &alloc);

    const int tfd = open(path_in.c_str(), O_RDONLY);
    if( tfd == -1 ) {
        Log::Warn("GetRealPath() failed to open '{}'", _path_in);
        return {};
    }
    char path_buf[MAXPATHLEN];
    const int ret = fcntl(tfd, F_GETPATH, path_buf);
    close(tfd);
    if( ret == -1 ) {
        Log::Warn("GetRealPath() failed to F_GETPATH of '{}', errno: {}", _path_in, errno);
        return {};
    }

    std::string path_out(path_buf);
    if( !path_out.empty() && path_out.back() != '/' )
        path_out += '/';

    return path_out;
}

bool FSEventsDirUpdateImpl::ShouldFire(const std::string_view _watched_path,
                                       const size_t _num_events,
                                       const char *_event_paths[],
                                       const FSEventStreamEventFlags _event_flags[]) noexcept
{
    assert(!_watched_path.empty() && _watched_path.back() == '/');

    for( size_t i = 0; i < _num_events; i++ ) {
        const auto flags = _event_flags[i];
        if( flags & kFSEventStreamEventFlagRootChanged ) {
            return true;
        }
        else {
            // this checking should be blazing fast, since we can get A LOT of events here
            // (from all sub-dirs) and we need only events from current-level directory
            const auto path = std::string_view{_event_paths[i]};
            if( path.empty() ) {
                continue;
            }

            // the input paths may or may not contain trailing slashes, that likely depends on an fs driver(?)
            if( path.back() == '/' ) {
                // regular comparison
                if( path == _watched_path )
                    return true;
            }
            else {
                // compare discarding the trailing slash of the watcher's path
                if( path == _watched_path.substr(0, _watched_path.length() - 1) )
                    return true;
            }
        }
    }
    return false;
}

void FSEventsDirUpdateImpl::FSEventsDirUpdateCallback([[maybe_unused]] ConstFSEventStreamRef _stream_ref,
                                                      void *_user_data,
                                                      size_t _num,
                                                      void *_paths,
                                                      const FSEventStreamEventFlags _flags[],
                                                      [[maybe_unused]] const FSEventStreamEventId _ids[])
{
    // WTF this data access is not locked????

    Log::Trace("FSEventsDirUpdate::Impl::FSEventsDirUpdateCallback for {} path(s): {}",
               _num,
               fmt::join(std::span<const char *>{reinterpret_cast<const char **>(_paths), _num}, ", "));

    const WatchData &watch = *static_cast<const WatchData *>(_user_data);
    if( ShouldFire(watch.path, _num, reinterpret_cast<const char **>(_paths), _flags) ) {
        for( auto &h : watch.handlers )
            h.second();
    }
}

FSEventStreamRef FSEventsDirUpdateImpl::CreateEventStream(const std::string &path, void *context_ptr)
{
    Log::Debug("CreateEventStream called for '{}'", path);
    auto cf_path = base::CFStringCreateWithUTF8StdString(path);
    if( !cf_path ) {
        Log::Warn("CreateEventStream failed to create a CFStringRef for '{}'", path);
        return nullptr;
    }

    CFArrayRef pathsToWatch = CFArrayCreate(nullptr, reinterpret_cast<const void **>(&cf_path), 1, nullptr);
    FSEventStreamRef stream = nullptr;
    auto create_stream = [&] {
        const auto flags = kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot;
        auto context = FSEventStreamContext{0, context_ptr, nullptr, nullptr, nullptr};
        stream = FSEventStreamCreate(nullptr,
                                     &FSEventsDirUpdateImpl::FSEventsDirUpdateCallback,
                                     &context,
                                     pathsToWatch,
                                     kFSEventStreamEventIdSinceNow,
                                     g_FSEventsLatency,
                                     flags);
        if( stream == nullptr ) {
            Log::Warn("FSEventStreamCreate failed to create a stream for '{}'", path);
        }
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

    auto schedule_and_run = [=] {
        FSEventStreamScheduleWithRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        const bool started = FSEventStreamStart(_stream);
        if( !started ) {
            Log::Error("FSEventStreamStart failed to start");
        }
    };

    if( dispatch_is_main_queue() )
        schedule_and_run();
    else
        dispatch_to_main_queue(schedule_and_run);
}

// Stops and deletes the _stream
static void StopStream(FSEventStreamRef _stream)
{
    assert(_stream != nullptr);
    dispatch_assert_main_queue();
    FSEventStreamStop(_stream);
    FSEventStreamUnscheduleFromRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

    // FSEventStreamInvalidate can be blocking, so let's do that in a background thread
    dispatch_to_background([_stream] {
        FSEventStreamInvalidate(_stream);
        FSEventStreamRelease(_stream);
    });
}

uint64_t FSEventsDirUpdateImpl::AddWatchPath(std::string_view _path, std::function<void()> _handler)
{
    if( _path.empty() || !_handler )
        return no_ticket;

    Log::Debug("FSEventsDirUpdate::Impl::AddWatchPath called for '{}'", _path);

    // convert _path into canonical path of OS
    const auto dir_path = GetRealPath(_path);
    if( dir_path.empty() ) {
        Log::Debug("Failed to get a real path of '{}'", _path);
        return no_ticket;
    }

    // monotonically increase current ticket to get a next unique one
    const auto ticket = m_LastTicket++;

    auto lock = std::lock_guard{m_Lock};

    // check if this path already presents in watched paths
    if( auto it = m_Watches.find(dir_path); it != m_Watches.end() ) {
        Log::Trace("Using an already existing watcher for '{}'", _path);
        it->second->handlers.emplace_back(ticket, std::move(_handler));
        return ticket;
    }

    // create a new watch stream
    Log::Trace("Creating a new watcher for '{}'", _path);
    auto ep = m_Watches.emplace(dir_path, std::make_unique<WatchData>());
    assert(ep.second == true);
    WatchData &w = *ep.first->second;
    w.stream = CreateEventStream(dir_path, &w);
    if( w.stream == nullptr ) {
        // failed to creat the event stream, roll back the changes and return a failure indication
        m_Watches.erase(ep.first);
        return no_ticket;
    }
    w.path = ep.first->first;
    w.handlers.emplace_back(ticket, std::move(_handler));
    StartStream(w.stream);

    return ticket;
}

// Erases an element at '_i' from containers '_c' by swapping it with the last element and then removing the last
// element. That's to cause less data movements
template <class Container, class Iterator>
static inline void unordered_erase(Container &_c, Iterator _i)
{
    // can do this since erase() requires a valid iterator => thus c is not empty.
    auto last = std::prev(std::end(_c));

    if( last != _i )
        std::iter_swap(_i, last);

    _c.erase(last);
}

void FSEventsDirUpdateImpl::RemoveWatchPathWithTicket(uint64_t _ticket)
{
    if( _ticket == no_ticket )
        return;

    if( !dispatch_is_main_queue() ) {
        dispatch_to_main_queue([=, this] { RemoveWatchPathWithTicket(_ticket); });
        return;
    }

    auto lock = std::lock_guard{m_Lock};

    for( auto i = m_Watches.begin(), e = m_Watches.end(); i != e; ++i ) {
        auto &watch = *i->second;
        for( auto h = watch.handlers.begin(), he = watch.handlers.end(); h != he; ++h )
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

void FSEventsDirUpdateImpl::OnVolumeDidUnmount(const std::string &_on_path)
{
    // when a volume is removed from the system we force every relevant panel to reload its data
    dispatch_assert_main_queue();
    // locking??
    for( auto &i : m_Watches ) {
        if( i.second->path.starts_with(_on_path) ) {
            for( auto &h : i.second->handlers )
                h.second();
        }
    }
}

} // namespace nc::utility
