// Copyright (C) 2021-203 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FSEventsFileUpdateImpl.h"
#include "UnitTests_main.h"
#include <CoreFoundation/CoreFoundation.h>
#include <Base/mach_time.h>
#include <fcntl.h>
#include <chrono>
#include <thread>

using nc::utility::FSEventsFileUpdateImpl;
using namespace std::chrono_literals;

#define PREFIX "nc::utility::FSEventsFileUpdateImpl "

static bool run_until_timeout_or_predicate(std::chrono::nanoseconds _timeout,
                                           std::chrono::nanoseconds _slice,
                                           std::function<bool()> _done);

TEST_CASE(PREFIX "Constructible/destructible")
{
    const FSEventsFileUpdateImpl file_update;
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
    const TempTestDir tmp_dir;
    FSEventsFileUpdateImpl file_update;
    bool fired = false;
    auto callback = [&] { fired = true; };
    SECTION("File created")
    {
        const auto path = tmp_dir.directory / "file_0.txt";
        file_update.AddWatchPath(path, callback);
        close(open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU));
    }
    SECTION("File deleted")
    {
        const auto path = tmp_dir.directory / "file_1.txt";
        close(open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU));
        file_update.AddWatchPath(path, callback);
        unlink(path.c_str());
    }
    SECTION("File renamed")
    {
        const auto path = tmp_dir.directory / "file_2.txt";
        close(open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU));
        file_update.AddWatchPath(path, callback);
        std::filesystem::rename(path, tmp_dir.directory / "new_filename.txt");
    }
    SECTION("Existing file contents changed")
    {
        const auto path = tmp_dir.directory / "file_3.txt";
        const int file = open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU);
        file_update.AddWatchPath(path, callback);
        write(file, "hello", 5);
        close(file);
    }
    SECTION("Existing file contents changed, existing content")
    {
        const auto path = tmp_dir.directory / "file_4.txt";
        const int file = open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU);
        write(file, "hello", 5);
        file_update.AddWatchPath(path, callback);
        write(file, "hello", 5);
        close(file);
    }
    SECTION("Existing file contents changed, O_SHLOCK")
    {
        const auto path = tmp_dir.directory / "file_5.txt";
        const int file = open(path.c_str(), O_CREAT | O_RDWR | O_SHLOCK, S_IRWXU);
        file_update.AddWatchPath(path, callback);
        write(file, "hello", 5);
        close(file);
    }
    SECTION("Existing file contents changed, O_EXLOCK")
    {
        const auto path = tmp_dir.directory / "file_6.txt";
        const int file = open(path.c_str(), O_CREAT | O_RDWR | O_EXLOCK, S_IRWXU);
        file_update.AddWatchPath(path, callback);
        write(file, "hello", 5);
        close(file);
    }
    //    SECTION("Existing file handle closed")
    //    {
    //        // THIS IS NOT CAUGHT
    //        const auto path = tmp_dir.directory / "file_7.txt";
    //        int file = open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU);
    //        file_update.AddWatchPath(path, callback);
    //        close(file);
    //    }
    SECTION("Existing file contents changed, no closure")
    {
        const auto path = tmp_dir.directory / "file_8.txt";
        const int file = open(path.c_str(), O_CREAT | O_RDWR, S_IRWXU);
        write(file, "hello", 5);
        file_update.AddWatchPath(path, callback);
        std::vector<unsigned char> nonsense(1'000);
        write(file, nonsense.data(), nonsense.size());
        // deliberately leaking the file handle
    }
    REQUIRE(run_until_timeout_or_predicate(5s, 10ms, [&] { return fired; }));
}

static bool run_until_timeout_or_predicate(std::chrono::nanoseconds _timeout,
                                           std::chrono::nanoseconds _slice,
                                           std::function<bool()> _done)
{
    assert(_done);
    const auto deadline = nc::base::machtime() + _timeout;
    do {
        if( _done() )
            return true;
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, std::chrono::duration<double>(_slice).count(), false);
    } while( deadline > nc::base::machtime() );
    return false;
}
