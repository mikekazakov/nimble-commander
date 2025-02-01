// Copyright (C) 2020-2024 Michael Kazakov. Subject to GNU General Public License version 3.

#include <Base/intrusive_ptr.h>
#include "UnitTests_main.h"
#include <vector>
#include <thread>

#define PREFIX "nc::base::intrusive_ptr "

using nc::base::intrusive_ptr;
// NOLINTBEGIN(bugprone-use-after-move)

namespace {

struct Counted : nc::base::intrusive_ref_counter<Counted> {
    Counted() { ++alive; }
    Counted(const Counted &) = delete;
    ~Counted() { --alive; }
    Counted &operator=(const Counted &) = delete;
    static std::atomic_int alive;
};

std::atomic_int Counted::alive{0};

} // namespace

TEST_CASE(PREFIX "Default constructor")
{
    const intrusive_ptr<Counted> ptr;
    CHECK(ptr.get() == nullptr);
}

TEST_CASE(PREFIX "nullptr constructor")
{
    const intrusive_ptr<Counted> ptr{nullptr};
    CHECK(ptr.get() == nullptr);
}

TEST_CASE(PREFIX "normal pointer constructor")
{
    Counted *raw_ptr = new Counted;
    CHECK(Counted::alive == 1);
    {
        const intrusive_ptr<Counted> ptr{raw_ptr};
        CHECK(ptr.get() == raw_ptr);
    }
    CHECK(Counted::alive == 0);
}

TEST_CASE(PREFIX "copy constructor")
{
    SECTION("Empty")
    {
        const intrusive_ptr<Counted> ptr1;
        intrusive_ptr<Counted> ptr2{ptr1}; // NOLINT
        CHECK(ptr1.get() == nullptr);
        CHECK(ptr2.get() == nullptr);
    }
    SECTION("Non-empty")
    {
        Counted *raw_ptr = new Counted;
        CHECK(Counted::alive == 1);
        {
            const intrusive_ptr<Counted> ptr1{raw_ptr};
            {
                intrusive_ptr<Counted> ptr2{ptr1}; // NOLINT
                CHECK(ptr1.get() == raw_ptr);
                CHECK(ptr2.get() == raw_ptr);
                CHECK(Counted::alive == 1);
            }
            CHECK(Counted::alive == 1);
        }
        CHECK(Counted::alive == 0);
    }
}

TEST_CASE(PREFIX "converting copy constructor")
{
    Counted *raw_ptr = new Counted;
    CHECK(Counted::alive == 1);
    {
        const intrusive_ptr<Counted> ptr1{raw_ptr};
        {
            const intrusive_ptr<const Counted> ptr2{ptr1};
            CHECK(ptr1.get() == raw_ptr);
            CHECK(ptr2.get() == raw_ptr);
            CHECK(Counted::alive == 1);
        }
        CHECK(Counted::alive == 1);
    }
    CHECK(Counted::alive == 0);
}

TEST_CASE(PREFIX "move constructor")
{
    SECTION("Empty")
    {
        intrusive_ptr<Counted> ptr1;
        const intrusive_ptr<Counted> ptr2{std::move(ptr1)};
        CHECK(ptr1.get() == nullptr);
        CHECK(ptr2.get() == nullptr);
    }
    SECTION("Non-empty")
    {
        Counted *raw_ptr = new Counted;
        CHECK(Counted::alive == 1);
        {
            intrusive_ptr<Counted> ptr1{raw_ptr};
            {
                const intrusive_ptr<Counted> ptr2{std::move(ptr1)};
                CHECK(ptr1.get() == nullptr);
                CHECK(ptr2.get() == raw_ptr);
                CHECK(Counted::alive == 1);
            }
            CHECK(Counted::alive == 0);
        }
        CHECK(Counted::alive == 0);
    }
}

TEST_CASE(PREFIX "converting move constructor")
{
    SECTION("Empty")
    {
        intrusive_ptr<Counted> ptr1;
        const intrusive_ptr<const Counted> ptr2{std::move(ptr1)};
        CHECK(ptr1.get() == nullptr);
        CHECK(ptr2.get() == nullptr);
    }
    SECTION("Non-empty")
    {
        Counted *raw_ptr = new Counted;
        CHECK(Counted::alive == 1);
        {
            intrusive_ptr<Counted> ptr1{raw_ptr};
            {
                const intrusive_ptr<const Counted> ptr2{std::move(ptr1)};
                CHECK(ptr1.get() == nullptr);
                CHECK(ptr2.get() == raw_ptr);
                CHECK(Counted::alive == 1);
            }
            CHECK(Counted::alive == 0);
        }
        CHECK(Counted::alive == 0);
    }
}

TEST_CASE(PREFIX "copy assignment operator")
{
    SECTION("Empty->Empty")
    {
        const intrusive_ptr<Counted> ptr1;
        intrusive_ptr<Counted> ptr2;
        ptr2 = ptr1;
        CHECK(ptr2.get() == nullptr);
    }
    SECTION("Empty->NonEmpty")
    {
        Counted *raw_ptr = new Counted;
        CHECK(Counted::alive == 1);
        {
            const intrusive_ptr<Counted> ptr1{raw_ptr};
            intrusive_ptr<Counted> ptr2;
            ptr2 = ptr1;
            CHECK(ptr2.get() == raw_ptr);
            CHECK(Counted::alive == 1);
        }
        CHECK(Counted::alive == 0);
    }
    SECTION("NonEmpty->Empty")
    {
        Counted *raw_ptr = new Counted;
        CHECK(Counted::alive == 1);
        {
            const intrusive_ptr<Counted> ptr1;
            intrusive_ptr<Counted> ptr2{raw_ptr};
            ptr2 = ptr1;
            CHECK(ptr2.get() == nullptr);
            CHECK(Counted::alive == 0);
        }
        CHECK(Counted::alive == 0);
    }
    SECTION("NonEmpty->NonEmpty")
    {
        Counted *raw_ptr1 = new Counted;
        Counted *raw_ptr2 = new Counted;
        CHECK(Counted::alive == 2);
        {
            const intrusive_ptr<Counted> ptr1{raw_ptr1};
            intrusive_ptr<Counted> ptr2{raw_ptr2};
            ptr2 = ptr1;
            CHECK(ptr2.get() == raw_ptr1);
            CHECK(Counted::alive == 1);
        }
        CHECK(Counted::alive == 0);
    }
}

TEST_CASE(PREFIX "move assignment operator")
{
    SECTION("Empty->Empty")
    {
        intrusive_ptr<Counted> ptr1;
        intrusive_ptr<Counted> ptr2;
        ptr2 = std::move(ptr1);
        CHECK(ptr1.get() == nullptr);
        CHECK(ptr2.get() == nullptr);
    }
    SECTION("Empty->NonEmpty")
    {
        Counted *raw_ptr = new Counted;
        CHECK(Counted::alive == 1);
        {
            intrusive_ptr<Counted> ptr1{raw_ptr};
            intrusive_ptr<Counted> ptr2;
            ptr2 = std::move(ptr1);
            CHECK(ptr1.get() == nullptr);
            CHECK(ptr2.get() == raw_ptr);
            CHECK(Counted::alive == 1);
        }
        CHECK(Counted::alive == 0);
    }
    SECTION("NonEmpty->Empty")
    {
        Counted *raw_ptr = new Counted;
        CHECK(Counted::alive == 1);
        {
            intrusive_ptr<Counted> ptr1;
            intrusive_ptr<Counted> ptr2{raw_ptr};
            ptr2 = std::move(ptr1);
            CHECK(ptr1.get() == nullptr);
            CHECK(ptr2.get() == nullptr);
            CHECK(Counted::alive == 0);
        }
        CHECK(Counted::alive == 0);
    }
    SECTION("NonEmpty->NonEmpty")
    {
        Counted *raw_ptr1 = new Counted;
        Counted *raw_ptr2 = new Counted;
        CHECK(Counted::alive == 2);
        {
            intrusive_ptr<Counted> ptr1{raw_ptr1};
            intrusive_ptr<Counted> ptr2{raw_ptr2};
            ptr2 = std::move(ptr1);
            CHECK(ptr1.get() == nullptr);
            CHECK(ptr2.get() == raw_ptr1);
            CHECK(Counted::alive == 1);
        }
        CHECK(Counted::alive == 0);
    }
}

TEST_CASE(PREFIX "nullptr assignment operator")
{
    SECTION("Empty")
    {
        intrusive_ptr<Counted> ptr;
        ptr = nullptr;
        CHECK(ptr.get() == nullptr);
    }
    SECTION("Non-empty")
    {
        Counted *raw_ptr = new Counted;
        CHECK(Counted::alive == 1);
        {
            intrusive_ptr<Counted> ptr{raw_ptr};
            ptr = nullptr;
            CHECK(Counted::alive == 0);
        }
        CHECK(Counted::alive == 0);
    }
}

TEST_CASE(PREFIX "reset()")
{
    SECTION("Empty")
    {
        intrusive_ptr<Counted> ptr;
        ptr.reset();
        CHECK(ptr.get() == nullptr);
    }
    SECTION("Non-empty")
    {
        Counted *raw_ptr = new Counted;
        CHECK(Counted::alive == 1);
        {
            intrusive_ptr<Counted> ptr{raw_ptr};
            ptr.reset();
            CHECK(Counted::alive == 0);
        }
        CHECK(Counted::alive == 0);
    }
}

TEST_CASE(PREFIX "reset(U*)")
{
    SECTION("Empty")
    {
        intrusive_ptr<Counted> ptr;
        ptr.reset(static_cast<Counted *>(nullptr));
        CHECK(ptr.get() == nullptr);
    }
    SECTION("Non-empty")
    {
        Counted *raw_ptr = new Counted;
        CHECK(Counted::alive == 1);
        {
            intrusive_ptr<Counted> ptr;
            ptr.reset(raw_ptr);
            CHECK(Counted::alive == 1);
        }
        CHECK(Counted::alive == 0);
    }
    SECTION("Non-empty, convertion")
    {
        Counted *raw_ptr = new Counted;
        CHECK(Counted::alive == 1);
        {
            intrusive_ptr<const Counted> ptr;
            ptr.reset(raw_ptr);
            CHECK(Counted::alive == 1);
        }
        CHECK(Counted::alive == 0);
    }
}

TEST_CASE(PREFIX "release")
{
    SECTION("Empty")
    {
        intrusive_ptr<Counted> ptr;
        auto p = ptr.release();
        CHECK(ptr.get() == nullptr);
        CHECK(p == nullptr);
    }
    SECTION("Non-empty")
    {
        Counted *raw_ptr = new Counted;
        CHECK(Counted::alive == 1);
        {
            intrusive_ptr<Counted> ptr{raw_ptr};
            auto p = ptr.release();
            CHECK(ptr.get() == nullptr);
            CHECK(p == raw_ptr);
            CHECK(Counted::alive == 1);
        }
        delete raw_ptr;
        CHECK(Counted::alive == 0);
    }
}

TEST_CASE(PREFIX "operator*")
{
    Counted *raw_ptr = new Counted;
    const intrusive_ptr<Counted> ptr{raw_ptr};
    CHECK(&(*ptr) == raw_ptr);
}

TEST_CASE(PREFIX "operator->")
{
    SECTION("Empty")
    {
        const intrusive_ptr<Counted> ptr;
        CHECK(ptr.operator->() == nullptr);
    }
    SECTION("Non-empty")
    {
        Counted *raw_ptr = new Counted;
        const intrusive_ptr<Counted> ptr{raw_ptr};
        CHECK(ptr.operator->() == raw_ptr);
    }
}

TEST_CASE(PREFIX "swap()")
{
    Counted *raw_ptr1 = new Counted;
    Counted *raw_ptr2 = new Counted;
    intrusive_ptr<Counted> ptr1{raw_ptr1};
    intrusive_ptr<Counted> ptr2{raw_ptr2};
    SECTION("method")
    {
        ptr1.swap(ptr2);
    }
    SECTION("std::swap")
    {
        std::swap(ptr1, ptr2);
    }
    CHECK(ptr1.get() == raw_ptr2);
    CHECK(ptr2.get() == raw_ptr1);
}

TEST_CASE(PREFIX "Memory order correctness")
{
    Counted *raw_ptr = new Counted;

    std::vector<std::thread> threads;
    {
        const intrusive_ptr<Counted> ptr{raw_ptr};
        for( int i = 0; i < 1000; ++i )
            threads.emplace_back([ptr] { /* destroy ptr */ });
        CHECK(Counted::alive == 1);
    }
    for( auto &thread : threads )
        thread.join();

    CHECK(Counted::alive == 0);
}

TEST_CASE(PREFIX "use_count()")
{
    Counted *raw_ptr = new Counted;
    REQUIRE(raw_ptr->use_count() == 0);

    const intrusive_ptr<Counted> ptr1{raw_ptr};
    REQUIRE(raw_ptr->use_count() == 1);
    REQUIRE(raw_ptr->use_count() == ptr1->use_count());
    {
        // NOLINTBEGIN(performance-unnecessary-copy-initialization)
        const intrusive_ptr<Counted> ptr2{ptr1};
        REQUIRE(raw_ptr->use_count() == 2);
        REQUIRE(raw_ptr->use_count() == ptr1->use_count());
        REQUIRE(raw_ptr->use_count() == ptr2->use_count());
        // NOLINTEND(performance-unnecessary-copy-initialization)
    }
    REQUIRE(raw_ptr->use_count() == 1);
    REQUIRE(raw_ptr->use_count() == ptr1->use_count());
}

// NOLINTEND(bugprone-use-after-move)
