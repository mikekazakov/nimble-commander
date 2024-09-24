// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BlinkScheduler.h"
#include "UnitTests_main.h"
#include <optional>

using nc::utility::BlinkScheduler;
using namespace std::chrono;

#define PREFIX "nc::utility::BlinkScheduler "

namespace {

struct StubIO : BlinkScheduler::IO {
    struct Dispatched {
        std::chrono::nanoseconds after;
        std::function<void()> what;
    };

    std::chrono::nanoseconds now;
    std::shared_ptr<Dispatched> dispatched;

    std::chrono::nanoseconds Now() noexcept override { return now; }
    void Dispatch(std::chrono::nanoseconds _after, std::function<void()> _what) noexcept override
    {
        dispatched = std::make_shared<Dispatched>(Dispatched{.after = _after, .what = std::move(_what)});
    }
};

} // namespace

TEST_CASE(PREFIX "Constructor throws on invalid parameters")
{
    CHECK_THROWS_AS(BlinkScheduler(std::function<void()>{}), std::invalid_argument);
    CHECK_THROWS_AS(BlinkScheduler([] {}, 0s), std::invalid_argument);
    CHECK_THROWS_AS(BlinkScheduler([] {}, -5s), std::invalid_argument);
}

TEST_CASE(PREFIX "Disabled by default")
{
    const BlinkScheduler bs([] {});
    CHECK(bs.Enabled() == false);
}

TEST_CASE(PREFIX "Visible when disabled")
{
    const BlinkScheduler bs([] {});
    CHECK(bs.Visible() == true);
}

TEST_CASE(PREFIX "Shedules at time divisible by blink_time after enabling")
{
    StubIO io;
    SECTION("Exact")
    {
        io.now = 5s;
        BlinkScheduler bs([] {}, 500ms, io);
        bs.Enable(true);
        REQUIRE(io.dispatched);
        CHECK(io.dispatched->after == 500ms);
    }
    SECTION("Off + ")
    {
        io.now = 5100ms;
        BlinkScheduler bs([] {}, 500ms, io);
        bs.Enable(true);
        REQUIRE(io.dispatched);
        CHECK(io.dispatched->after == 400ms);
    }
    SECTION("Off - ")
    {
        io.now = 4900ms;
        BlinkScheduler bs([] {}, 500ms, io);
        bs.Enable(true);
        REQUIRE(io.dispatched);
        CHECK(io.dispatched->after == 100ms);
    }
}

TEST_CASE(PREFIX "Enabling twice doesn't shedule twice")
{
    StubIO io;
    BlinkScheduler bs([] {}, 500ms, io);
    bs.Enable(true);
    io.dispatched.reset();
    bs.Enable(true);
    CHECK(io.dispatched == nullptr);
}

TEST_CASE(PREFIX "Enabling after disabling doesn't shedule twice")
{
    StubIO io;
    BlinkScheduler bs([] {}, 500ms, io);
    bs.Enable(true);
    io.dispatched.reset();
    bs.Enable(false);
    bs.Enable(true);
    CHECK(io.dispatched == nullptr);
}

TEST_CASE(PREFIX "Enable -> Disable -> Fire => not scheduled ")
{
    StubIO io;
    BlinkScheduler bs([] {}, 500ms, io);
    bs.Enable(true);
    bs.Enable(false);
    auto dispatched = io.dispatched;
    io.dispatched.reset();
    dispatched->what();
    CHECK(io.dispatched == nullptr);
}

TEST_CASE(PREFIX "Enable -> Disable -> Fire -> Enable => scheduled ")
{
    StubIO io;
    BlinkScheduler bs([] {}, 500ms, io);
    bs.Enable(true);
    bs.Enable(false);
    auto dispatched = io.dispatched;
    io.dispatched.reset();
    dispatched->what();
    bs.Enable(true);
    CHECK(io.dispatched);
}

TEST_CASE(PREFIX "Enable -> Fire => scheduled ")
{
    StubIO io;
    BlinkScheduler bs([] {}, 500ms, io);
    bs.Enable(true);
    auto dispatched = io.dispatched;
    io.dispatched.reset();
    dispatched->what();
    CHECK(io.dispatched);
}

TEST_CASE(PREFIX "Enable -> Fire (Disable) => not scheduled ")
{
    StubIO io;
    BlinkScheduler *bsp = nullptr;
    BlinkScheduler bs([&bsp] { bsp->Enable(false); }, 500ms, io);
    bsp = &bs;
    bs.Enable(true);
    auto dispatched = io.dispatched;
    io.dispatched.reset();
    dispatched->what();
    CHECK(io.dispatched == nullptr);
}

TEST_CASE(PREFIX "Disabling after enabling returns in callback not executed")
{
    StubIO io;
    bool fired = false;
    auto on_blink = [&fired] { fired = true; };
    BlinkScheduler bs(on_blink, 500ms, io);
    bs.Enable(true);
    bs.Enable(false);
    REQUIRE(io.dispatched);
    REQUIRE(io.dispatched->what);
    io.dispatched->what();
    CHECK(fired == false);
}

TEST_CASE(PREFIX "Shedules the right callback")
{
    StubIO io;
    bool fired = false;
    auto on_blink = [&fired] { fired = true; };
    BlinkScheduler bs(on_blink, 500ms, io);
    bs.Enable(true);
    REQUIRE(io.dispatched);
    REQUIRE(io.dispatched->what);
    io.dispatched->what();
    CHECK(fired == true);
}

TEST_CASE(PREFIX "Alternates visibility between fires based on absolute time")
{
    StubIO io;
    SECTION("Starts with visible")
    {
        io.now = 1000ms;
        BlinkScheduler bs([] {}, 500ms, io);
        CHECK(bs.Visible() == true);
        bs.Enable(true);
        CHECK(bs.Visible() == true);
        auto dispatched = io.dispatched;
        dispatched->what();
        CHECK(bs.Visible() == false);
        dispatched = io.dispatched;
        dispatched->what();
        CHECK(bs.Visible() == true);
        dispatched = io.dispatched;
        dispatched->what();
        CHECK(bs.Visible() == false);
    }
    SECTION("Starts with hidden")
    {
        io.now = 1500ms;
        BlinkScheduler bs([] {}, 500ms, io);
        CHECK(bs.Visible() == true);
        bs.Enable(true);
        CHECK(bs.Visible() == false);
        auto dispatched = io.dispatched;
        dispatched->what();
        CHECK(bs.Visible() == true);
        dispatched = io.dispatched;
        dispatched->what();
        CHECK(bs.Visible() == false);
        dispatched = io.dispatched;
        dispatched->what();
        CHECK(bs.Visible() == true);
    }
    SECTION("Recalculates visibility upon enabling")
    {
        io.now = 0ms;
        BlinkScheduler *bsp = nullptr;
        BlinkScheduler bs([&bsp] { bsp->Enable(false); }, 500ms, io);
        bsp = &bs;
        bs.Enable(true);
        CHECK(bs.Visible() == true);
        io.dispatched->what();
        io.now = 2500ms;
        bs.Enable(true);
        CHECK(bs.Visible() == false);
    }
}
