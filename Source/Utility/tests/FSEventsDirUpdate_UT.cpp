// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FSEventsDirUpdate.h"
#include "FSEventsDirUpdateImpl.h"
#include "UnitTests_main.h"
#include <Base/dispatch_cpp.h>
#include <CoreFoundation/CoreFoundation.h>
#include <fcntl.h>

using nc::utility::FSEventsDirUpdate;
using nc::utility::FSEventsDirUpdateImpl;
using namespace std::chrono_literals;

#define PREFIX "nc::utility::FSEventsDirUpdate "

static void touch(const std::string &_path);
static bool runMainLoopUntilExpectationOrTimeout(std::chrono::nanoseconds _timeout, std::function<bool()> _expectation);

TEST_CASE(PREFIX "Returns zero on invalid paths")
{
    auto &inst = FSEventsDirUpdate::Instance();
    CHECK(inst.AddWatchPath("/asdasd/asdasdsa", [] {}) == 0);
}

TEST_CASE(PREFIX "Registers event listeners")
{
    const TempTestDir tmp_dir;
    auto &inst = FSEventsDirUpdate::Instance();
    int call_count[3] = {0, 0, 0};

    const auto ticket0 = inst.AddWatchPath(tmp_dir.directory.c_str(), [&] { ++call_count[0]; });

    touch(tmp_dir.directory / "something.txt");
    REQUIRE(runMainLoopUntilExpectationOrTimeout(5s, [&] { return call_count[0] == 1; }));

    const auto ticket1 = inst.AddWatchPath(tmp_dir.directory.c_str(), [&] { ++call_count[1]; });

    touch(tmp_dir.directory / "something else.txt");
    REQUIRE(runMainLoopUntilExpectationOrTimeout(5s, [&] { return call_count[0] == 2 && call_count[1] == 1; }));

    const auto ticket2 = inst.AddWatchPath(tmp_dir.directory.c_str(), [&] { ++call_count[2]; });

    touch(tmp_dir.directory / "another something else.txt");
    REQUIRE(runMainLoopUntilExpectationOrTimeout(
        5s, [&] { return call_count[0] == 3 && call_count[1] == 2 && call_count[2] == 1; }));

    inst.RemoveWatchPathWithTicket(ticket0);
    inst.RemoveWatchPathWithTicket(ticket1);
    inst.RemoveWatchPathWithTicket(ticket2);
}

TEST_CASE(PREFIX "Removes event listeners")
{
    const TempTestDir tmp_dir;
    auto &inst = FSEventsDirUpdate::Instance();
    int call_count[3] = {0, 0, 0};

    const auto ticket0 = inst.AddWatchPath(tmp_dir.directory.c_str(), [&] { ++call_count[0]; });

    touch(tmp_dir.directory / "something.txt");
    REQUIRE(runMainLoopUntilExpectationOrTimeout(5s, [&] { return call_count[0] == 1; }));

    inst.RemoveWatchPathWithTicket(ticket0);
    const auto ticket1 = inst.AddWatchPath(tmp_dir.directory.c_str(), [&] { ++call_count[1]; });

    touch(tmp_dir.directory / "something else.txt");
    REQUIRE(runMainLoopUntilExpectationOrTimeout(5s, [&] { return call_count[0] == 1 && call_count[1] == 1; }));

    const auto ticket2 = inst.AddWatchPath(tmp_dir.directory.c_str(), [&] { ++call_count[2]; });

    touch(tmp_dir.directory / "another something else.txt");
    REQUIRE(runMainLoopUntilExpectationOrTimeout(
        5s, [&] { return call_count[0] == 1 && call_count[1] == 2 && call_count[2] == 1; }));

    inst.RemoveWatchPathWithTicket(ticket1);
    inst.RemoveWatchPathWithTicket(ticket2);
}

TEST_CASE(PREFIX "Firing logic")
{
    using I = FSEventsDirUpdateImpl;
    struct TC {
        std::string_view watched_path;
        std::vector<const char *> event_paths;
        std::vector<FSEventStreamEventFlags> event_flags;
        bool exp = false;
    } tcs[] = {
        {.watched_path = "/dir/", .event_paths = {}, .event_flags = {}, .exp = false},
        {.watched_path = "/dir/", .event_paths = {""}, .event_flags = {0}, .exp = false},
        {.watched_path = "/dir/", .event_paths = {"/"}, .event_flags = {0}, .exp = false},
        {.watched_path = "/dir/", .event_paths = {"/di"}, .event_flags = {0}, .exp = false},
        {.watched_path = "/dir/", .event_paths = {"/dir"}, .event_flags = {0}, .exp = true},
        {.watched_path = "/dir/", .event_paths = {"/dir/"}, .event_flags = {0}, .exp = true},
        {.watched_path = "/dir/", .event_paths = {"/dirr"}, .event_flags = {0}, .exp = false},
        {.watched_path = "/dir/", .event_paths = {"/dirr/"}, .event_flags = {0}, .exp = false},
        {.watched_path = "/dir/", .event_paths = {"/dir/sub"}, .event_flags = {0}, .exp = false},
        {.watched_path = "/dir/", .event_paths = {"/dir/sub/"}, .event_flags = {0}, .exp = false},
        {.watched_path = "/dir/", .event_paths = {"/else", "/dir/"}, .event_flags = {0, 0}, .exp = true},
        {.watched_path = "/dir/", .event_paths = {"/else/", "/dir"}, .event_flags = {0, 0}, .exp = true},
        {.watched_path = "/dir/",
         .event_paths = {"/else", "/another/"},
         .event_flags = {kFSEventStreamEventFlagRootChanged, 0},
         .exp = true},
        {.watched_path = "/dir/",
         .event_paths = {"/else", "/another/"},
         .event_flags = {0, kFSEventStreamEventFlagRootChanged},
         .exp = true},
    };

    for( auto &tc : tcs ) {
        assert(tc.event_paths.size() == tc.event_flags.size());
        const bool result =
            I::ShouldFire(tc.watched_path, tc.event_paths.size(), tc.event_paths.data(), tc.event_flags.data());
        CHECK(result == tc.exp);
    }
}

static void touch(const std::string &_path)
{
    close(open(_path.c_str(), O_CREAT | O_RDWR, S_IRWXU));
}

static bool runMainLoopUntilExpectationOrTimeout(std::chrono::nanoseconds _timeout, std::function<bool()> _expectation)
{
    dispatch_assert_main_queue();
    assert(_timeout.count() > 0);
    assert(_expectation);
    const auto start_tp = std::chrono::steady_clock::now();
    const auto time_slice = 1. / 100.; // 10 ms;
    while( true ) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, time_slice, false);
        if( std::chrono::steady_clock::now() - start_tp > _timeout )
            return false;
        if( _expectation() )
            return true;
    }
}
