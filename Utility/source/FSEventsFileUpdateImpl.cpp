// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FSEventsFileUpdateImpl.h"
#include <Utility/StringExtras.h>
#include <Habanero/CFPtr.h>
#include <Habanero/dispatch_cpp.h>
#include <iostream>

namespace nc::utility {

static const CFAbsoluteTime g_FSEventsLatency = 0.05; // 50ms

size_t
FSEventsFileUpdateImpl::PathHash::operator()(const std::filesystem::path &_path) const noexcept
{
    return robin_hood::hash_bytes(_path.native().c_str(), _path.native().size());
}

size_t FSEventsFileUpdateImpl::PathHash::operator()(const std::string_view &_path) const noexcept
{
    return robin_hood::hash_bytes(_path.data(), _path.size());
}

FSEventsFileUpdateImpl::~FSEventsFileUpdateImpl()
{
    dispatch_is_main_queue();
    // there's no need to lock here because at this point no one can touch this object anymore
    for( auto &watch : m_Watches ) {
        DeleteEventStream(watch.second.stream);
    }
}

uint64_t FSEventsFileUpdateImpl::AddWatchPath(const std::filesystem::path &_path,
                                              std::function<void()> _handler)
{
    assert(_handler);
    auto lock = std::lock_guard{m_Lock};

    const auto token = m_NextTicket++;
    if( auto existing = m_Watches.find(_path); existing != m_Watches.end() ) {
        auto &watch = existing->second;
        assert(watch.handlers.contains(token) == false);
        watch.handlers.emplace(token, std::move(_handler));
    }
    else {
        auto stream = CreateEventStream(_path);
        if( stream == nullptr )
            return empty_token;
        Watch watch;
        watch.stream = stream;
        watch.handlers.emplace(token, std::move(_handler));
        m_Watches.emplace(_path, std::move(watch));
    }
    return token;
}

void FSEventsFileUpdateImpl::RemoveWatchPathWithToken(uint64_t _token)
{
    auto lock = std::lock_guard{m_Lock};
    for( auto watch_it = m_Watches.begin(), watch_end = m_Watches.end(); watch_it != watch_end;
         ++watch_it ) {
        auto &watch = watch_it->second;
        if( watch.handlers.contains(_token) ) {
            watch.handlers.erase(_token);
            if( watch.handlers.empty() ) {
                DeleteEventStream(watch.stream);
                m_Watches.erase(watch_it);
            }
            break;
        }
    }
}

FSEventStreamRef FSEventsFileUpdateImpl::CreateEventStream(const std::filesystem::path &_path) const
{
    auto cf_path = base::CFPtr<CFStringRef>::adopt(CFStringCreateWithUTF8StdString(_path.native()));
    if( !cf_path )
        return nullptr;

    const auto paths_to_watch = base::CFPtr<CFArrayRef>::adopt(
        CFArrayCreate(0, reinterpret_cast<const void **>(&cf_path), 1, nullptr));
    if( !paths_to_watch )
        return nullptr;

    const auto flags = kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents;
    auto context = FSEventStreamContext{
        0, const_cast<void *>(reinterpret_cast<const void *>(this)), nullptr, nullptr, nullptr};

    FSEventStreamRef stream = nullptr;
    auto create_schedule_and_run = [&] {
        stream = FSEventStreamCreate(nullptr,
                                     &FSEventsFileUpdateImpl::CallbackFFI,
                                     &context,
                                     paths_to_watch.get(),
                                     kFSEventStreamEventIdSinceNow,
                                     g_FSEventsLatency,
                                     flags);
        if( stream == nullptr )
            return;
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        FSEventStreamStart(stream);
    };

    if( dispatch_is_main_queue() )
        create_schedule_and_run();
    else
        dispatch_sync(dispatch_get_main_queue(), create_schedule_and_run);

    return stream;
}

void FSEventsFileUpdateImpl::DeleteEventStream(FSEventStreamRef _stream)
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

void FSEventsFileUpdateImpl::Callback([[maybe_unused]] ConstFSEventStreamRef _stream_ref,
                                      size_t _num,
                                      void *_paths,
                                      [[maybe_unused]] const FSEventStreamEventFlags _flags[],
                                      [[maybe_unused]] const FSEventStreamEventId _ids[]) const
{
    auto lock = std::lock_guard{m_Lock};
    auto paths = reinterpret_cast<const char **>(_paths);
    for( size_t i = 0; i != _num; ++i ) {
        assert(paths[i]);
        auto watches_it = m_Watches.find(paths[i]);
        if( watches_it != m_Watches.end() ) {
            for( auto &handler : watches_it->second.handlers ) {
                // NB! no copy here => this call is NOT reenterant!
                handler.second();
            }
        }
    }
}

void FSEventsFileUpdateImpl::CallbackFFI(ConstFSEventStreamRef _stream_ref,
                                         void *_user_data,
                                         size_t _num,
                                         void *_paths,
                                         const FSEventStreamEventFlags _flags[],
                                         const FSEventStreamEventId _ids[])
{
    const FSEventsFileUpdateImpl *me = static_cast<const FSEventsFileUpdateImpl *>(_user_data);
    me->Callback(_stream_ref, _num, _paths, _flags, _ids);
}

} // namespace nc::utility
