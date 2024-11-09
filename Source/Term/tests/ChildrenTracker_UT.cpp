// Copyright (C) 2023-2024 Michael Kazakov. Subject to GNU General Public License version 3.

#include "Tests.h"
#include "AtomicHolder.h"
#include "ChildrenTracker.h"
#include <thread>

using namespace nc;
using namespace nc::term;
using namespace std::chrono_literals;
#define PREFIX "nc::term::ChildrenTracker "

TEST_CASE(PREFIX "Generic cases", "[!mayfail]")
{
    const int p1 = getpid();
    QueuedAtomicHolder<int> ncalled{0};
    auto cb = [&ncalled, next = 1] mutable { ncalled.store(next++); };

    const ChildrenTracker tracker{p1, cb};

    SECTION("Nothing")
    {
    }
    SECTION("Single fork")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(1ms);
            exit(0);
        }
        CHECK(p2 > 0);
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p2 exit
        CHECK(waitpid(p2, nullptr, 0) == p2);
    }
    SECTION("Two sequent forks")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(1ms);
            exit(0);
        }
        CHECK(p2 > 0);
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p2 exit
        const int p3 = fork();
        if( p3 == 0 ) {
            std::this_thread::sleep_for(1ms);
            exit(0);
        }
        CHECK(p3 > 0);
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 3)); // p1 fork -> p3
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 4)); // p3 exit
        CHECK(waitpid(p2, nullptr, 0) == p2);
        CHECK(waitpid(p3, nullptr, 0) == p3);
    }
    SECTION("Two recursive forks")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(1ms);
            if( const int p3 = fork(); p3 == 0 ) {
                std::this_thread::sleep_for(1ms);
                exit(0);
            }
            else
                waitpid(p3, nullptr, 0);
            exit(0);
        }
        CHECK(p2 > 0);
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p2 fork -> p3
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 3)); // p3 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 4)); // p2 exit
        CHECK(waitpid(p2, nullptr, 0) == p2);
    }
    SECTION("Three recursive forks")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(1ms);
            if( const int p3 = fork(); p3 == 0 ) {
                std::this_thread::sleep_for(1ms);
                if( const int p4 = fork(); p4 == 0 ) {
                    std::this_thread::sleep_for(1ms);
                    exit(0);
                }
                else
                    waitpid(p4, nullptr, 0);
                exit(0);
            }
            else
                waitpid(p3, nullptr, 0);
            exit(0);
        }
        CHECK(p2 > 0);
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p2 fork -> p3
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 3)); // p3 fork -> p4
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 4)); // p4 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 5)); // p3 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 6)); // p2 exit
        CHECK(waitpid(p2, nullptr, 0) == p2);
    }
    SECTION("2 x two recursive forks")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(1ms);
            if( const int p3 = fork(); p3 == 0 ) {
                std::this_thread::sleep_for(1ms);
                exit(0);
            }
            else
                waitpid(p3, nullptr, 0);
            exit(0);
        }
        const int p4 = fork();
        if( p4 == 0 ) {
            std::this_thread::sleep_for(1ms);
            if( const int p3 = fork(); p3 == 0 ) {
                std::this_thread::sleep_for(1ms);
                exit(0);
            }
            else
                waitpid(p3, nullptr, 0);
            exit(0);
        }
        CHECK(p2 > 0);
        CHECK(p4 > 0);
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p1 fork -> p4
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 3)); // p2 fork -> p3
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 4)); // p4 fork -> p5
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 5)); // p3 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 6)); // p5 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 7)); // p2 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 8)); // p4 exit <-- this one fails on GHA
        CHECK(waitpid(p2, nullptr, 0) == p2);
        CHECK(waitpid(p4, nullptr, 0) == p4);
    }
    SECTION("Fork and exec")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(1ms);
            close(1);
            execl("/usr/bin/uptime", "uptime", nullptr);
        }
        CHECK(p2 > 0);
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p2 exec
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 3)); // p2 exit
        CHECK(waitpid(p2, nullptr, 0) == p2);
    }
    SECTION("Two recursive forks and exec")
    {
        const int p2 = fork();
        if( p2 == 0 ) {
            std::this_thread::sleep_for(1ms);
            if( const int p3 = fork(); p3 == 0 ) {
                std::this_thread::sleep_for(1ms);
                close(1);
                execl("/usr/bin/uptime", "uptime", nullptr);
            }
            else
                waitpid(p3, nullptr, 0);
            exit(0);
        }
        CHECK(p2 > 0);
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p2 fork -> p3
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 3)); // p3 exec
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 4)); // p3 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 5)); // p2 exit
        CHECK(waitpid(p2, nullptr, 0) == p2);
    }
}

TEST_CASE(PREFIX "Invalid input")
{
    const ChildrenTracker tracker{std::numeric_limits<int>::max(), [] { FAIL(); }};
    if( fork() == 0 ) {
        std::this_thread::sleep_for(1ms);
        exit(0);
    }
}
