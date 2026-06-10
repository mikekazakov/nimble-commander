// Copyright (C) 2023-2026 Michael Kazakov. Subject to GNU General Public License version 3.

#include "Tests.h"
#include "AtomicHolder.h"
#include "ChildrenTracker.h"
#include <thread>

#define PREFIX "nc::term::ChildrenTracker "

namespace ChildrenTrackerTest {

using namespace nc;
using namespace nc::term;
using namespace std::chrono_literals;

static int reap(const int pid)
{
    pid_t r = 0;
    do {
        r = waitpid(pid, nullptr, 0);
    } while( r == -1 && errno == EINTR );
    return r;
}

TEST_CASE(PREFIX "Generic cases")
{
    const int p1 = getpid();
    QueuedAtomicHolder<ChildrenTracker::Event> ncalled;
    ncalled.strict(false);

    auto cb = [&ncalled, current = ChildrenTracker::Event{}](ChildrenTracker::Event _event) mutable {
        current.forks += _event.forks;
        current.execs += _event.execs;
        current.exits += _event.exits;
        ncalled.store(current);
    };

    const ChildrenTracker tracker{p1, cb};
    CHECK(tracker.KnownProcesses() == 1); // expect only this single process and no children at the beginning

    SECTION("Nothing")
    {
    }
    SECTION("Single fork")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(10ms);
            exit(0);
        }
        CHECK(p2 > 0);
        // p1 fork -> p2
        // p2 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, {.forks = 1, .execs = 0, .exits = 1}, true));
        CHECK(reap(p2) == p2);
    }
    SECTION("Two sequent forks")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(10ms);
            exit(0);
        }
        CHECK(p2 > 0);
        // p1 fork -> p2
        // p2 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, {.forks = 1, .execs = 0, .exits = 1}, true));
        const int p3 = fork();
        if( p3 == 0 ) {
            std::this_thread::sleep_for(10ms);
            exit(0);
        }
        CHECK(p3 > 0);
        // p1 fork -> p3
        // p3 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, {.forks = 2, .execs = 0, .exits = 2}, true));
        CHECK(reap(p2) == p2);
        CHECK(reap(p3) == p3);
    }
    SECTION("Two recursive forks")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(10ms);
            if( const int p3 = fork(); p3 == 0 ) {
                std::this_thread::sleep_for(10ms);
                exit(0);
            }
            else
                reap(p3);
            exit(0);
        }
        CHECK(p2 > 0);
        // p1 fork -> p2
        // p2 fork -> p3
        // p3 exit
        // p2 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, {.forks = 2, .execs = 0, .exits = 2}, true));
        CHECK(reap(p2) == p2);
    }
    SECTION("Three recursive forks")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(10ms);
            if( const int p3 = fork(); p3 == 0 ) {
                std::this_thread::sleep_for(10ms);
                if( const int p4 = fork(); p4 == 0 ) {
                    std::this_thread::sleep_for(10ms);
                    exit(0);
                }
                else
                    reap(p4);
                exit(0);
            }
            else
                reap(p3);
            exit(0);
        }
        CHECK(p2 > 0);
        // p1 fork -> p2
        // p2 fork -> p3
        // p3 fork -> p4
        // p4 exit
        // p3 exit
        // p2 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, {.forks = 3, .execs = 0, .exits = 3}, true));
        CHECK(reap(p2) == p2);
    }
    SECTION("2 x two recursive forks")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(10ms);
            if( const int p3 = fork(); p3 == 0 ) {
                std::this_thread::sleep_for(10ms);
                exit(0);
            }
            else
                reap(p3);
            exit(0);
        }
        const int p4 = fork();
        if( p4 == 0 ) {
            std::this_thread::sleep_for(10ms);
            if( const int p3 = fork(); p3 == 0 ) {
                std::this_thread::sleep_for(10ms);
                exit(0);
            }
            else
                reap(p3);
            exit(0);
        }
        CHECK(p2 > 0);
        CHECK(p4 > 0);
        // p1 fork -> p2
        // p1 fork -> p4
        // p2 fork -> p3
        // p4 fork -> p5
        // p3 exit
        // p5 exit
        // p2 exit
        // p4 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, {.forks = 4, .execs = 0, .exits = 4}, true));
        CHECK(reap(p2) == p2);
        CHECK(reap(p4) == p4);
    }
    SECTION("Fork and exec")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(10ms);
            close(1);
            execl("/usr/bin/uptime", "uptime", nullptr);
        }
        CHECK(p2 > 0);
        // p1 fork -> p2
        // p2 exec
        // p2 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, {.forks = 1, .execs = 1, .exits = 1}, true));
        CHECK(reap(p2) == p2);
    }

    SECTION("Two recursive forks and exec")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(10ms);
            if( const int p3 = fork(); p3 == 0 ) {
                std::this_thread::sleep_for(10ms);
                close(1);
                execl("/usr/bin/uptime", "uptime", nullptr);
            }
            else
                reap(p3);
            exit(0);
        }
        CHECK(p2 > 0);
        // p1 fork -> p2
        // p2 fork -> p3
        // p3 exec
        // p3 exit
        // p2 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, {.forks = 2, .execs = 1, .exits = 2}, true));
        CHECK(reap(p2) == p2);
    }
}

TEST_CASE(PREFIX "Invalid input")
{
    const ChildrenTracker tracker{std::numeric_limits<int>::max(), [](ChildrenTracker::Event) { FAIL(); }};
    if( const int p = fork(); p == 0 ) {
        std::this_thread::sleep_for(10ms);
        exit(0);
    }
    else {
        CHECK(reap(p));
    }
}

} // namespace ChildrenTrackerTest

#undef PREFIX
