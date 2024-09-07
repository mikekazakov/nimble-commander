// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "FSEventsDirUpdate.h"
#include <DiskArbitration/DiskArbitration.h>
#include <CoreServices/CoreServices.h>
#include <Base/spinlock.h>
#include <filesystem>
#include <Base/UnorderedUtil.h>

namespace nc::utility {

class FSEventsDirUpdateImpl : public FSEventsDirUpdate
{
public:
    uint64_t AddWatchPath(const char *_path, std::function<void()> _handler) override;

    void RemoveWatchPathWithTicket(uint64_t _ticket) override;

    // Implementation detail exposed for testability
    static bool ShouldFire(std::string_view _watched_path,
                           size_t _num_events,
                           const char *_event_paths[],
                           const FSEventStreamEventFlags _event_flags[]) noexcept;

private:
    struct WatchData {
        std::string_view path; // canonical fs representation, should include a trailing slash. points into hashmap
        FSEventStreamRef stream = nullptr;
        std::vector<std::pair<uint64_t, std::function<void()>>> handlers;
    };

    using WatchesT = ankerl::unordered_dense::
        segmented_map<std::string, WatchData, UnorderedStringHashEqual, UnorderedStringHashEqual>;

    void OnVolumeDidUnmount(const std::string &_on_path) override;

    static void DiskDisappeared(DADiskRef disk, void *context);
    static void FSEventsDirUpdateCallback(ConstFSEventStreamRef streamRef,
                                          void *userData,
                                          size_t numEvents,
                                          void *eventPaths,
                                          const FSEventStreamEventFlags eventFlags[],
                                          const FSEventStreamEventId eventIds[]);
    static FSEventStreamRef CreateEventStream(const std::string &path, void *context);

    spinlock m_Lock;
    WatchesT m_Watches;                // path -> watch data;
    std::atomic_ulong m_LastTicket{1}; // no #0 ticket, it's an error code
};

} // namespace nc::utility
