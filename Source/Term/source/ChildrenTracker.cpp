// Copyright (C) 2023-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ChildrenTracker.h"
#include <Base/dispatch_cpp.h>
#include <algorithm>
#include <array>
#include <libproc.h>
#include <memory_resource>
#include <span>
#include <vector>

namespace nc::term {

static constexpr uint32_t g_Notes = NOTE_FORK | NOTE_EXEC | NOTE_EXIT;

// Returns a sorted array of the root pid and its children
static std::vector<pid_t> InitialPIDs(pid_t _root_pid)
{
    pid_t child_pids[4096];
    const int cnt = proc_listchildpids(_root_pid, child_pids, std::size(child_pids) * sizeof(pid_t));
    if( cnt < 1 ) {
        return {_root_pid};
    }
    else {
        std::vector<pid_t> res;
        res.reserve(cnt + 1);
        res.push_back(_root_pid);
        res.insert(res.end(), &child_pids[0], &child_pids[cnt]);
        std::ranges::sort(res);
        return res;
    }
}

static void Subscribe(const int _kq, const std::span<const pid_t> _pids)
{
    std::array<char, 4096> mem_buffer;
    std::pmr::monotonic_buffer_resource mem_resource(mem_buffer.data(), mem_buffer.size());
    std::pmr::vector<struct kevent> chg(_pids.size(), &mem_resource);
    for( size_t i = 0; i < _pids.size(); ++i )
        EV_SET(&chg[i], _pids[i], EVFILT_PROC, EV_ADD | EV_RECEIPT, g_Notes, 0, nullptr);
    kevent(_kq, chg.data(), static_cast<int>(chg.size()), nullptr, 0, nullptr);
}

static void Subscribe(const int _kq, const int _pid) noexcept
{
    struct kevent change;
    EV_SET(&change, _pid, EVFILT_PROC, EV_ADD | EV_RECEIPT, g_Notes, 0, nullptr);
    kevent(_kq, &change, 1, nullptr, 0, nullptr);
}

static void Unsubscribe(const int _kq, const int _pid) noexcept
{
    struct kevent change;
    EV_SET(&change, _pid, EVFILT_PROC, EV_DELETE | EV_RECEIPT, g_Notes, 0, nullptr);
    kevent(_kq, &change, 1, nullptr, 0, nullptr);
}

ChildrenTracker::ChildrenTracker(int _root_pid, std::function<void()> _cb)
    : m_RootPID(_root_pid), m_Callback(std::move(_cb))
{
    assert(m_Callback);
    m_Tracked = InitialPIDs(_root_pid);
    m_KQ = kqueue();
    Subscribe(m_KQ, m_Tracked);
    m_Queue = dispatch_queue_create("nc::term::ChildrenTracker event queue", DISPATCH_QUEUE_SERIAL);
    m_Source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, m_KQ, 0, m_Queue);
    dispatch_source_set_event_handler_f(m_Source, +[](void *_ctx) { static_cast<ChildrenTracker *>(_ctx)->Drain(); });
    dispatch_set_context(m_Source, this);
    dispatch_activate(m_Source);
}

ChildrenTracker::~ChildrenTracker()
{
    dispatch_group_t grp = dispatch_group_create();
    dispatch_group_async_f(
        grp, m_Queue, m_Source, +[](void *_ctx) { dispatch_source_cancel(static_cast<dispatch_source_t>(_ctx)); });
    dispatch_group_wait(grp, DISPATCH_TIME_FOREVER);
    dispatch_release(grp);
    dispatch_release(m_Source);
    dispatch_release(m_Queue);
    close(m_KQ);
}

void ChildrenTracker::Drain()
{
    struct kevent events[32];
    const int nevents = kevent(m_KQ, nullptr, 0, events, std::size(events), nullptr);

    int meaningful = 0;
    for( const struct kevent &event : std::span{events, static_cast<size_t>(std::max(nevents, 0))} ) {
        if( event.filter != EVFILT_PROC || (event.flags & EV_ERROR) == EV_ERROR ) {
            continue;
        }
        const pid_t pid = static_cast<pid_t>(event.ident);
        if( event.fflags & NOTE_FORK ) {
            ++meaningful;
            pid_t pids[4096];
            const int npids = proc_listchildpids(pid, pids, std::size(pids) * sizeof(pid_t));
            for( const pid_t child : std::span{pids, static_cast<size_t>(std::max(npids, 0))} ) {
                auto it = std::ranges::lower_bound(m_Tracked, child);
                if( it == m_Tracked.end() || *it != child ) {
                    Subscribe(m_KQ, child);
                    m_Tracked.insert(it, child);
                }
            }
        }
        if( event.fflags & NOTE_EXEC ) {
            ++meaningful;
        }
        if( event.fflags & NOTE_EXIT ) {
            ++meaningful;
            Unsubscribe(m_KQ, pid);
            auto it = std::ranges::lower_bound(m_Tracked, pid);
            if( it != m_Tracked.end() && *it == pid )
                m_Tracked.erase(it);
        }
    }

    for( int i = 0; i < meaningful; ++i )
        m_Callback();
}

int ChildrenTracker::pid() const
{
    return m_RootPID;
}

} // namespace nc::term
