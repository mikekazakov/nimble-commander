// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TemporaryNativeFileChangesSentinel.h"
#include <Base/algo.h>
#include <Base/Hash.h>
#include <Utility/FSEventsDirUpdate.h>
#include <VFS/Native.h>
#include <Base/mach_time.h>
#include <Base/dispatch_cpp.h>
#include <NimbleCommander/Bootstrap/NativeVFSHostInstance.h>

#include <algorithm>

static std::optional<std::vector<uint8_t>> CalculateFileHash(const std::string &_path)
{
    const int chunk_sz = 1 * 1024 * 1024;
    VFSFilePtr file;
    int rc = nc::bootstrap::NativeVFSHostInstance().CreateFile(_path.c_str(), file, nullptr);
    if( rc != 0 )
        return std::nullopt;

    rc = file->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock, nullptr);
    if( rc != 0 )
        return std::nullopt;

    auto buf = std::make_unique<uint8_t[]>(chunk_sz);
    nc::base::Hash h(nc::base::Hash::MD5);

    ssize_t rn = 0;
    while( (rn = file->Read(buf.get(), chunk_sz)) > 0 )
        h.Feed(buf.get(), rn);

    if( rn < 0 )
        return std::nullopt;

    return h.Final();
}

TemporaryNativeFileChangesSentinel &TemporaryNativeFileChangesSentinel::Instance()
{
    static auto inst = new TemporaryNativeFileChangesSentinel;
    return *inst;
}

bool TemporaryNativeFileChangesSentinel::WatchFile(const std::string &_path,
                                                   std::function<void()> _on_file_changed,
                                                   std::chrono::milliseconds _check_delay,
                                                   std::chrono::milliseconds _drop_delay)
{
    // 1st - read current file and it's MD5 hash
    auto file_hash = CalculateFileHash(_path);
    if( !file_hash )
        return false;

    auto current = std::make_shared<Meta>();
    auto &dir_update = nc::utility::FSEventsDirUpdate::Instance();
    const auto path = std::filesystem::path(_path).parent_path();
    const uint64_t watch_ticket = dir_update.AddWatchPath(
        path.c_str(), [current] { TemporaryNativeFileChangesSentinel::Instance().FSEventCallback(current); });
    if( !watch_ticket )
        return false;

    current->fswatch_ticket = watch_ticket;
    current->path = _path;
    current->callback = to_shared_ptr(std::move(_on_file_changed));
    current->last_md5_hash = std::move(*file_hash);
    current->drop_delay = _drop_delay;
    current->check_delay = _check_delay;

    ScheduleItemDrop(current);

    auto lock = std::lock_guard{m_WatchesLock};
    m_Watches.emplace_back(std::move(current));
    return true;
}

void TemporaryNativeFileChangesSentinel::ScheduleItemDrop(const std::shared_ptr<Meta> &_meta)
{
    using namespace std::chrono;
    static const auto safety_backlash = 100ms;
    _meta->drop_time = duration_cast<milliseconds>(nc::base::machtime() + _meta->drop_delay);
    dispatch_to_background_after(_meta->drop_delay + safety_backlash, [=, this] {
        if( _meta->drop_time < nc::base::machtime() )
            StopFileWatch(_meta->path);
    });
}

bool TemporaryNativeFileChangesSentinel::StopFileWatch(const std::string &_path)
{
    auto &dir_update = nc::utility::FSEventsDirUpdate::Instance();
    auto lock = std::lock_guard{m_WatchesLock};
    auto it = std::ranges::find_if(m_Watches, [&](const auto &_i) { return _i->path == _path; });
    if( it != end(m_Watches) ) {
        const auto &meta = *it;
        dir_update.RemoveWatchPathWithTicket(meta->fswatch_ticket);
        meta->fswatch_ticket = 0;
        m_Watches.erase(it);
    }
    return true;
}

void TemporaryNativeFileChangesSentinel::FSEventCallback(std::shared_ptr<Meta> _meta)
{
    dispatch_assert_main_queue();

    if( _meta->checking_now )
        return;

    _meta->checking_now = true;

    dispatch_to_background_after(_meta->check_delay, [=, this] { BackgroundItemCheck(_meta); });
}

void TemporaryNativeFileChangesSentinel::BackgroundItemCheck(std::shared_ptr<Meta> _meta)
{
    dispatch_assert_background_queue();
    auto clear_flag = at_scope_end([&] { _meta->checking_now = false; });

    auto current_hash = CalculateFileHash(_meta->path);
    if( !current_hash )
        return; // this file is not ok - just abort

    if( *current_hash != _meta->last_md5_hash ) {
        _meta->last_md5_hash = std::move(*current_hash);
        ScheduleItemDrop(_meta);

        auto client_callback = _meta->callback;
        dispatch_to_main_queue([=] { (*client_callback)(); });
    }
}
