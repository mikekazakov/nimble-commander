// Copyright (C) 2023-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ChildrenTracker.h"
#include "Log.h"
#include <Base/dispatch_cpp.h>
#include <algorithm>
#include <array>
#include <libproc.h>
#include <sys/proc.h>
#include <sys/proc_info.h>
#include <iostream>
#include <memory_resource>
#include <span>
#include <vector>
#include <thread>
#include <ranges>
#include <fmt/format.h>
#include <fmt/ranges.h>
#include <fmt/ostream.h>
#include <signal.h>

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

static bool Subscribe(const int _kq, const int _pid) noexcept
{
    struct kevent change = {};
    struct kevent result = {};
    EV_SET(&change, _pid, EVFILT_PROC, EV_ADD | EV_RECEIPT, g_Notes, 0, nullptr);
    const int res = kevent(_kq, &change, 1, &result, 1, nullptr);
    if( res < 0 )
        return false;
    // EV_RECEIPT always sets EV_ERROR; data == 0 means success
    return result.data == 0;
}

static void Unsubscribe(const int _kq, const int _pid) noexcept
{
    struct kevent change;
    EV_SET(&change, _pid, EVFILT_PROC, EV_DELETE | EV_RECEIPT, g_Notes, 0, nullptr);
    kevent(_kq, &change, 1, nullptr, 0, nullptr);
}

ChildrenTracker::ChildrenTracker(int _root_pid, std::function<void(Event _event)> _cb)
    : m_RootPID(_root_pid), m_Callback(std::move(_cb))
{
    assert(m_Callback);
    const std::vector<pid_t> initial_pids = InitialPIDs(_root_pid);

    m_KQ = kqueue();

    for( const pid_t pid : initial_pids ) {
        struct proc_bsdshortinfo bsd_info;
        const int pidinfo_ret = proc_pidinfo(pid, PROC_PIDT_SHORTBSDINFO, 0, &bsd_info, sizeof(bsd_info));
        if( pidinfo_ret != sizeof(bsd_info) ) {
            continue; // process might have died and reaped since we got the pid, skip it
        }
        if( bsd_info.pbsi_status == SZOMB ) {
            continue; // no zombies allowed
        }

        if( !Subscribe(m_KQ, pid) ) {
            continue; // failed to subscribe, some other issue => skip
        }

        m_Tracked.push_back({.pid = pid, .status = bsd_info.pbsi_status});
    }

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
    Log::Debug("ChildrenTracker::Drain() called");

    // Use this opportunity to clean up the zombies that were already reaped
    std::erase_if(m_Tracked, [](ProcessInfo &_process) {
        if( _process.status == SZOMB ) {
            // Verify that either the process was reaped or even already recycled (ABA)
            struct proc_bsdshortinfo bsd_info;
            const int pidinfo_ret = proc_pidinfo(_process.pid, PROC_PIDT_SHORTBSDINFO, 0, &bsd_info, sizeof(bsd_info));
            if( pidinfo_ret != sizeof(bsd_info) ) {
                Log::Trace("ChildrenTracker: Process with PID {} was reaped", _process.pid);
                return true; // already reaped, just remove it
            }
            // The process with this PID is now longer a zombie => we have an ABA here
            const bool pid_reused = bsd_info.pbsi_status != SZOMB;
            if( pid_reused ) {
                Log::Trace("ChildrenTracker: Process with PID {} was reaped and PID was reused for a new process",
                           _process.pid);
            }
            return pid_reused;
        }
        return false;
    });

    struct kevent events[32];
    const int nevents = kevent(m_KQ, nullptr, 0, events, std::size(events), nullptr);
    Event callback_event;
    const std::span<const struct kevent> events_span{events, static_cast<size_t>(std::max(nevents, 0))};
    for( const struct kevent &event : events_span ) {
        Log::Trace("ChildrenTracker: Received event for PID={} with filter={} and flags={:#x}",
                   event.ident,
                   event.filter,
                   event.fflags);
        if( event.filter != EVFILT_PROC || (event.flags & EV_ERROR) == EV_ERROR ) {
            continue;
        }
        const pid_t pid = static_cast<pid_t>(event.ident);
        if( event.fflags & NOTE_FORK ) {

            pid_t pids[4096];
            const int npids = proc_listchildpids(pid, pids, std::size(pids) * sizeof(pid_t));
            const std::span<const pid_t> pids_span{pids, static_cast<size_t>(std::max(npids, 0))};
            Log::Trace("ChildrenTracker: Process with PID {} forked, current child PIDs: {}", pid, pids_span);
            for( const pid_t child : pids_span ) {
                auto it = std::ranges::lower_bound(m_Tracked, child, {}, &ProcessInfo::pid);
                if( it == m_Tracked.end() || it->pid != child ) {
                    // We haven't seen this process before, let's take a closer look at it...

                    // Check the process status before subscribing to its events, it might be a zombie
                    struct proc_bsdshortinfo bsd_info;
                    const int pidinfo_ret = proc_pidinfo(child, PROC_PIDT_SHORTBSDINFO, 0, &bsd_info, sizeof(bsd_info));
                    if( pidinfo_ret != sizeof(bsd_info) ) {
                        Log::Info("ChildrenTracker: unable to get info for child process with PID {}", child);
                        continue; // process might have died and reaped since we got the pid, skip it
                    }

                    if( bsd_info.pbsi_status == SZOMB ) {
                        // The child process is already a zombie, make a mark for ourselves, but don't subscribe to it
                        // (no events won't come anyway). Since it's the first time the process appeared, and it's
                        // already a zombie, issue a fork + exit event for it.
                        Log::Trace("ChildrenTracker: Child process with PID {} is already a zombie", child);
                        ++callback_event.forks;
                        ++callback_event.exits;
                        m_Tracked.insert(it, {.pid = child, .status = SZOMB});
                        continue;
                    }

                    // Now try to subscribe to the events from this process
                    const bool subscribed = Subscribe(m_KQ, child);
                    if( subscribed ) {
                        // All is nice and dandy, supposedly...
                        // NB! A TOCTOU remains here - here's a small chance that process
                        // exists AFTER the proc_pidinfo() call and BEFORE the Subscribe() call,
                        // this leads to a situation when NOTE_EXIT will never be delivered.
                        Log::Trace("ChildrenTracker: Subscribed to child process with PID {}", child);
                        ++callback_event.forks;
                        m_Tracked.insert(it, {.pid = child, .status = bsd_info.pbsi_status});
                    }
                    else {
                        // Failed to subscribe, pronounce it dead and list as a zombie
                        Log::Info(
                            "ChildrenTracker: unable to subscribe to child process with PID {}, assuming it's a zombie",
                            child);
                        ++callback_event.forks;
                        ++callback_event.exits;
                        m_Tracked.insert(it, {.pid = child, .status = SZOMB});
                    }
                }
            }
        }
        if( event.fflags & NOTE_EXEC ) {
            ++callback_event.execs;
        }
        if( event.fflags & NOTE_EXIT ) {
            ++callback_event.exits;
            Unsubscribe(m_KQ, pid);

            auto it = std::ranges::lower_bound(m_Tracked, pid, {}, &ProcessInfo::pid);
            if( it != m_Tracked.end() && it->pid == pid ) {
                it->status = SZOMB;
            }
        }
    }

    if( callback_event.forks == 0 && std::ranges::any_of(events_span, [](const struct kevent &_event) -> bool {
            return _event.fflags & NOTE_FORK;
        }) ) {
        // We're in a bit of pickle here...
        // There was a report of a fork yet we didn't manage to register any.
        // This can happen when the child process was already existed and reaped before we got to it.
        // Not much we can do about it, but at least let's invent a synthetic event for this situation.
        Log::Info("ChildrenTracker: Detected a fork event, but no the new child process, inventing fork+exit");
        ++callback_event.forks;
        ++callback_event.exits;
    }

    if( callback_event.forks > 0 || //
        callback_event.execs > 0 || //
        callback_event.exits > 0 ) {
        Log::Trace("ChildrenTracker: Emitting callback with {}", fmt::streamed(callback_event));
        m_Callback(callback_event);
    }
}

int ChildrenTracker::pid() const
{
    return m_RootPID;
}

size_t ChildrenTracker::KnownProcesses() const
{
    return m_Tracked.size();
}

std::ostream &operator<<(std::ostream &_os, const ChildrenTracker::Event &_event)
{
    _os << fmt::format("Event{{ forks: {}, execs: {}, exits: {} }}", _event.forks, _event.execs, _event.exits);
    return _os;
}

} // namespace nc::term
