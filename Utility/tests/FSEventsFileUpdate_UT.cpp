// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FSEventsFileUpdateImpl.h"
#include "UnitTests_main.h"
#include <CoreFoundation/CoreFoundation.h>
#include <Habanero/mach_time.h>
#include <fcntl.h>
#include <chrono>

using nc::utility::FSEventsFileUpdateImpl;
using namespace std::chrono_literals;

#define PREFIX "nc::utility::FSEventsFileUpdateImpl "

static bool run_until_timeout_or_predicate(std::chrono::nanoseconds _timeout,
                                           std::chrono::nanoseconds _slice,
                                           std::function<bool()> _done);

TEST_CASE(PREFIX "Constructible/destructible")
{
    FSEventsFileUpdateImpl file_update;
}

TEST_CASE(PREFIX "AddWatchPath to a nonexistent path")
{
    FSEventsFileUpdateImpl file_update;
    auto path = "/some_nonexistent_file!!!.txt";
    const auto token1 = file_update.AddWatchPath(path, [] {});
    REQUIRE(token1 != FSEventsFileUpdateImpl::empty_token);

    const auto token2 = file_update.AddWatchPath(path, [] {});
    REQUIRE(token2 != FSEventsFileUpdateImpl::empty_token);
    REQUIRE(token1 != token2);
}

TEST_CASE(PREFIX "RemoveWatchPathWithToken")
{
    FSEventsFileUpdateImpl file_update;
    auto path = "/some_nonexistent_file!!!.txt";
    const auto token1 = file_update.AddWatchPath(path, [] {});
    const auto token2 = file_update.AddWatchPath(path, [] {});
    SECTION("")
    {
        file_update.RemoveWatchPathWithToken(token1);
        file_update.RemoveWatchPathWithToken(token2);
    }
    SECTION("")
    {
        file_update.RemoveWatchPathWithToken(token2);
        file_update.RemoveWatchPathWithToken(token1);
    }
}

TEST_CASE(PREFIX "Notify from file events")
{
    TempTestDir tmp_dir;
    FSEventsFileUpdateImpl file_update;
    const auto path = tmp_dir.directory / "file.txt";
    bool fired = false;
    auto callback = [&] { fired = true; };

    SECTION("File created")
    {
        file_update.AddWatchPath(path, callback);
        close(open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU));
    }
    SECTION("File deleted")
    {
        close(open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU));
        file_update.AddWatchPath(path, callback);
        unlink(path.c_str());
    }
    SECTION("File renamed")
    {
        close(open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU));
        file_update.AddWatchPath(path, callback);
        std::filesystem::rename(path, tmp_dir.directory / "new_filename.txt");
    }
    SECTION("Existing file contents changed")
    {
        int file = open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU);
        file_update.AddWatchPath(path, callback);
        write(file, "hello", 5);
        close(file);
    }
    SECTION("Existing file handle closed")
    {
        int file = open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU);
        file_update.AddWatchPath(path, callback);
        close(file);
    }
    REQUIRE(run_until_timeout_or_predicate(5s, 10ms, [&] { return fired; }));
}

static bool run_until_timeout_or_predicate(std::chrono::nanoseconds _timeout,
                                           std::chrono::nanoseconds _slice,
                                           std::function<bool()> _done)
{
    assert(_done);
    const auto deadline = machtime() + _timeout;
    do {
        if( _done() )
            return true;
        CFRunLoopRunInMode(
            kCFRunLoopDefaultMode, std::chrono::duration<double>(_slice).count(), false);
    } while( deadline > machtime() );
    return false;
}
