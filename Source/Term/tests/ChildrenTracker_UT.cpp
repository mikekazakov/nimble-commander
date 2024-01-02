// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.

#include "Tests.h"
#include "AtomicHolder.h"
#include "ChildrenTracker.h"
#include <thread>

using namespace nc;
using namespace nc::term;
using namespace std::chrono_literals;
#define PREFIX "nc::term::ChildrenTracker "

TEST_CASE(PREFIX "Generic cases")
{
    const int mypid = getpid();
    QueuedAtomicHolder<int> ncalled{0};
    auto cb = [&ncalled, next = 1] mutable { ncalled.store(next++); };

    ChildrenTracker tracker{mypid, cb};

    SECTION("Nothing") {}
    SECTION("Single fork")
    {
        int p2;
        if( (p2 = fork()) == 0 ) {
            std::this_thread::sleep_for(1ms);
            exit(0);
        }
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p2 exit
        waitpid(p2, nullptr, 0);
    }
    SECTION("Two sequent forks")
    {
        if( fork() == 0 ) {
            std::this_thread::sleep_for(1ms);
            exit(0);
        }
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p2 exit
        if( fork() == 0 ) {
            std::this_thread::sleep_for(1ms);
            exit(0);
        }
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 3)); // p1 fork -> p3
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 4)); // p3 exit
    }
    SECTION("Two recursive forks")
    {
        if( fork() == 0 ) {
            std::this_thread::sleep_for(1ms);
            if( int p3; (p3 = fork()) == 0 ) {
                std::this_thread::sleep_for(1ms);
                exit(0);
            }
            else
                waitpid(p3, nullptr, 0);
            exit(0);
        }
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p2 fork -> p3
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 3)); // p3 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 4)); // p2 exit
    }
    SECTION("Three recursive forks")
    {
        if( fork() == 0 ) {
            std::this_thread::sleep_for(1ms);
            if( int p3; (p3 = fork()) == 0 ) {
                std::this_thread::sleep_for(1ms);
                if( int p4; (p4 = fork()) == 0 ) {
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
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p2 fork -> p3
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 3)); // p3 fork -> p4
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 4)); // p4 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 5)); // p3 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 6)); // p2 exit
    }
    SECTION("2 x two recursive forks")
    {
        if( fork() == 0 ) {
            std::this_thread::sleep_for(1ms);
            if( int p3; (p3 = fork()) == 0 ) {
                std::this_thread::sleep_for(1ms);
                exit(0);
            }
            else
                waitpid(p3, nullptr, 0);
            exit(0);
        }
        if( fork() == 0 ) {
            std::this_thread::sleep_for(1ms);
            if( int p3; (p3 = fork()) == 0 ) {
                std::this_thread::sleep_for(1ms);
                exit(0);
            }
            else
                waitpid(p3, nullptr, 0);
            exit(0);
        }
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p1 fork -> p4
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 3)); // p2 fork -> p3
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 4)); // p4 fork -> p5
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 5)); // p3 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 6)); // p5 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 7)); // p2 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 8)); // p4 exit
    }
    SECTION("Fork and exec")
    {
        if( fork() == 0 ) {
            std::this_thread::sleep_for(1ms);
            close(1);
            execl("/usr/bin/uptime", "uptime", nullptr);
        }
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p2 exec
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 3)); // p2 exit
    }
    SECTION("Two recursive forks and exec")
    {
        if( fork() == 0 ) {
            std::this_thread::sleep_for(1ms);
            if( int p3; (p3 = fork()) == 0 ) {
                std::this_thread::sleep_for(1ms);
                close(1);
                execl("/usr/bin/uptime", "uptime", nullptr);
            }
            else
                waitpid(p3, nullptr, 0);
            exit(0);
        }
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 1)); // p1 fork -> p2
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 2)); // p2 fork -> p3
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 3)); // p3 exec
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 4)); // p3 exit
        CHECK(ncalled.wait_to_become_with_runloop(5s, 1ms, 5)); // p2 exit
    }
}

TEST_CASE(PREFIX "Invalid input")
{
    ChildrenTracker tracker{std::numeric_limits<int>::max(), [] { FAIL(); }};
    if( fork() == 0 ) {
        std::this_thread::sleep_for(1ms);
        exit(0);
    }
}
