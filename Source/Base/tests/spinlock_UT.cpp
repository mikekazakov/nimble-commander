// Copyright (C) 2018-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "spinlock.h"
#include "UnitTests_main.h"
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
    std::atomic_int value = 0;
    nc::spinlock lock;

    auto th1 = std::thread{[&] {
        auto guard = std::lock_guard{lock};
        CHECK(value == 0);
        std::this_thread::sleep_for(std::chrono::milliseconds{10});
        value = 1;
    }};
    std::this_thread::sleep_for(std::chrono::milliseconds{1});
    auto th2 = std::thread{[&] {
        auto guard = std::lock_guard{lock};
        CHECK(value == 1);
        value = 2;
    }};

    th1.join();
    th2.join();
    CHECK(value == 2);
}
