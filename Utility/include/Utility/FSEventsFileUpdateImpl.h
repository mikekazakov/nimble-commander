// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "FSEventsFileUpdate.h"
#include <CoreServices/CoreServices.h>
#include <robin_hood.h>
#include <vector>
#include <mutex>

namespace nc::utility {

class FSEventsFileUpdateImpl : FSEventsFileUpdate
{
public:
    ~FSEventsFileUpdateImpl();
    uint64_t AddWatchPath(const std::filesystem::path &_path,
                          std::function<void()> _handler) override;

    void RemoveWatchPathWithToken(uint64_t _token) override;

    using FSEventsFileUpdate::empty_token;

private:
    struct Watch {
        FSEventStreamRef stream;
        robin_hood::unordered_flat_map<uint64_t, std::function<void()>> handlers;
    };

    struct PathHash {
        using is_transparent = void;
        size_t operator()(const std::filesystem::path &_path) const noexcept;
        size_t operator()(const std::string_view &_path) const noexcept;
    };

    FSEventStreamRef CreateEventStream(const std::filesystem::path &_path) const;
    static void DeleteEventStream(FSEventStreamRef _stream);
    void Callback(ConstFSEventStreamRef _stream_ref,
                  size_t _num,
                  void *_paths,
                  const FSEventStreamEventFlags _flags[],
                  const FSEventStreamEventId _ids[]) const;
    static void CallbackFFI(ConstFSEventStreamRef _stream_ref,
                            void *_user_data,
                            size_t _num,
                            void *_paths,
                            const FSEventStreamEventFlags _flags[],
                            const FSEventStreamEventId _ids[]);

    robin_hood::unordered_map<std::filesystem::path, Watch, PathHash> m_Watches;
    mutable std::mutex m_Lock;
    uint64_t m_NextTicket = 1;
};

} // namespace nc::utility
