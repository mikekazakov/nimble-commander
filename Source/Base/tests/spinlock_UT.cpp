// Copyright (C) 2018-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include "spinlock.h"
#include "UnitTests_main.h"
#include <array>
#include <string>
#include <thread>
#include <atomic>

#define PREFIX "spinlock "

TEST_CASE(PREFIX "non-contested passage")
{
    bool flag = false;
    nc::spinlock lock;
    {
        auto guard = std::lock_guard{lock};
        flag = true;
    }
    CHECK(flag == true);
}

TEST_CASE(PREFIX "contested passage")
{
    constexpr int num_threads = 8;
    constexpr int increments_per_thread = 10000;

    nc::spinlock lock;
    int counter = 0;

    auto worker = [&]() {
        for( int i = 0; i < increments_per_thread; ++i ) {
            auto guard = std::lock_guard{lock};
            ++counter;
        }
    };

    std::array<std::thread, num_threads> threads;
    for( int i = 0; i < num_threads; ++i ) {
        threads[i] = std::thread(worker);
    }

    for( auto &t : threads ) {
        t.join();
    }

    CHECK(counter == num_threads * increments_per_thread);
}

#undef PREFIX
