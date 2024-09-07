// Copyright (C) 2021-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "FSEventsFileUpdate.h"
#include <CoreServices/CoreServices.h>
#include <ankerl/unordered_dense.h>
#include <vector>
#include <optional>
#include <mutex>
#include <sys/stat.h>

namespace nc::utility {

class FSEventsFileUpdateImpl : public FSEventsFileUpdate
{
public:
    FSEventsFileUpdateImpl();
    FSEventsFileUpdateImpl(const FSEventsFileUpdateImpl &) = delete;
    ~FSEventsFileUpdateImpl();
    void operator=(const FSEventsFileUpdateImpl &) = delete;

    uint64_t AddWatchPath(const std::filesystem::path &_path, std::function<void()> _handler) override;

    void RemoveWatchPathWithToken(uint64_t _token) override;

    using FSEventsFileUpdate::empty_token;

private:
    struct Watch {
        FSEventStreamRef stream;
        std::optional<struct stat> stat;
        std::chrono::nanoseconds snapshot_time;
        ankerl::unordered_dense::map<uint64_t, std::function<void()>> handlers;
    };
    struct AsyncContext {
        FSEventsFileUpdateImpl *me = nullptr;
    };
    struct PathHash {
        using is_transparent = void;
        size_t operator()(const std::filesystem::path &_path) const noexcept;
        size_t operator()(const std::string_view &_path) const noexcept;
    };
    struct PathEqual {
        using is_transparent = void;
        bool operator()(const std::filesystem::path &_lhs, const std::filesystem::path &_rhs) const noexcept;
        bool operator()(std::string_view _lhs, const std::filesystem::path &_rhs) const noexcept;
    };

    void ScheduleScannerKickstart();
    void KickstartBackgroundScanner();
    void AcceptScannedStats(const std::vector<std::filesystem::path> &_paths,
                            const std::vector<std::optional<struct stat>> &_stats);
    static void BackgroundScanner(std::vector<std::filesystem::path> _paths,
                                  std::weak_ptr<AsyncContext> _context) noexcept;
    static bool DidChange(const std::optional<struct stat> &_was, const std::optional<struct stat> &_now) noexcept;

    FSEventStreamRef CreateEventStream(const std::filesystem::path &_path) const;
    static void DeleteEventStream(FSEventStreamRef _stream);
    void Callback(ConstFSEventStreamRef _stream_ref,
                  size_t _num,
                  void *_paths,
                  const FSEventStreamEventFlags _flags[],
                  const FSEventStreamEventId _ids[]);
    static void CallbackFFI(ConstFSEventStreamRef _stream_ref,
                            void *_user_data,
                            size_t _num,
                            void *_paths,
                            const FSEventStreamEventFlags _flags[],
                            const FSEventStreamEventId _ids[]);

    ankerl::unordered_dense::map<std::filesystem::path, Watch, PathHash, PathEqual> m_Watches;
    mutable std::mutex m_Lock;
    dispatch_queue_t m_KickstartQueue;
    uint64_t m_NextTicket = 1;
    bool m_KickstartIsOnline = false;
    std::shared_ptr<AsyncContext> m_AsyncContext;   // the only strong ownership
    std::weak_ptr<AsyncContext> m_WeakAsyncContext; // 'points' at m_AsyncContext
};

} // namespace nc::utility
