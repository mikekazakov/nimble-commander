// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include <Base/algo.h>
#include <Base/dispatch_cpp.h>
#include <NativeFSManagerImpl.h>
#include <algorithm>
#include <boost/process.hpp>
#include <filesystem>

using nc::utility::NativeFileSystemInfo;
using nc::utility::NativeFSManagerImpl;
#define PREFIX "nc::utility::NativeFSManager "

static bool runMainLoopUntilExpectationOrTimeout(std::chrono::nanoseconds _timeout, std::function<bool()> _expectation);
static int Execute(const std::string &_command);

TEST_CASE(PREFIX "Fast lookup considers firmlinks")
{
    if( !std::filesystem::exists("/Applications/") )
        return; // on CI environment it's possible that this directory does not exist

    const NativeFSManagerImpl fsm;

    auto root_volume = fsm.VolumeFromPathFast("/");
    REQUIRE(root_volume != nullptr);
    CHECK(root_volume->mounted_at_path == "/");

    auto applications_volume = fsm.VolumeFromPathFast("/Applications/");
    REQUIRE(applications_volume != nullptr);
    CHECK(applications_volume != root_volume);
}

TEST_CASE(PREFIX "VolumeFromFD")
{
    const auto p1 = "/bin";
    const auto p2 = "/Users";

    const int fd1 = open(p1, O_RDONLY);
    REQUIRE(fd1 >= 0);
    auto close_fd1 = at_scope_end([=] { close(fd1); });

    const int fd2 = open(p2, O_RDONLY);
    REQUIRE(fd2 >= 0);
    auto close_fd2 = at_scope_end([=] { close(fd2); });

    const NativeFSManagerImpl fsm;
    const auto info1 = fsm.VolumeFromFD(fd1);
    REQUIRE(info1 != nullptr);
    CHECK(info1->mounted_at_path == "/");

    const auto info2 = fsm.VolumeFromFD(fd2);
    REQUIRE(info2 != nullptr);
    CHECK(info2->mounted_at_path == "/System/Volumes/Data"); // this can be flaky (?)

    const auto info1_p = fsm.VolumeFromPath(p1);
    CHECK(info1_p == info1);

    const auto info2_p = fsm.VolumeFromPath(p2);
    CHECK(info2_p == info2);
}

TEST_CASE(PREFIX "Can detect filesystem mounts and unmounts")
{
    using namespace std::chrono_literals;
    const TempTestDir tmp_dir;
    const auto dmg_path = tmp_dir.directory / "tmp_image.dmg";

    NativeFSManagerImpl fsm;
    auto create_cmd =
        "/usr/bin/hdiutil create -size 1m -fs HFS+ -volname SomethingWickedThisWayComes12345 " + dmg_path.native();
    auto mount_cmd = "/usr/bin/hdiutil attach " + dmg_path.native();
    auto unmount_cmd = "/usr/bin/hdiutil detach /Volumes/SomethingWickedThisWayComes12345";
    auto volume_path = "/Volumes/SomethingWickedThisWayComes12345";

    {
        REQUIRE(Execute(create_cmd) == 0);
        REQUIRE(Execute(mount_cmd) == 0);
        auto unmount = at_scope_end([&] { Execute(unmount_cmd); });

        auto predicate = [&]() -> bool {
            auto volumes = fsm.Volumes();
            return std::ranges::any_of(volumes,
                                       [&](const auto &volume) { return volume->mounted_at_path == volume_path; });
        };
        REQUIRE(runMainLoopUntilExpectationOrTimeout(10s, predicate));

        auto volume = fsm.VolumeFromMountPoint(volume_path);
        REQUIRE(volume);
        CHECK(volume->mounted_at_path == volume_path);
        CHECK(volume->fs_type_name == "hfs");
        CHECK(volume->basic.total_bytes == 1007616);
    }

    auto predicate = [&]() -> bool {
        auto volumes = fsm.Volumes();
        return std::ranges::none_of(volumes,
                                    [&](const auto &volume) { return volume->mounted_at_path == volume_path; });
    };
    REQUIRE(runMainLoopUntilExpectationOrTimeout(10s, predicate));
}

TEST_CASE(PREFIX "Can detect filesystem renames", "[!mayfail]")
{
    using namespace std::chrono_literals;
    const TempTestDir tmp_dir;
    const auto dmg_path = tmp_dir.directory / "tmp_image.dmg";

    auto create_cmd =
        "/usr/bin/hdiutil create -size 1m -fs HFS+ -volname SomethingWickedThisWayComes12345 " + dmg_path.native();
    auto mount_cmd = "/usr/bin/hdiutil attach " + dmg_path.native();
    auto rename_cmd = "/usr/sbin/diskutil rename /Volumes/SomethingWickedThisWayComes12345 "
                      "SomethingWickedThisWayComes123456";
    auto unmount_cmd = "/usr/bin/hdiutil detach /Volumes/SomethingWickedThisWayComes123456";
    auto volume_path_old = "/Volumes/SomethingWickedThisWayComes12345";
    auto volume_path_new = "/Volumes/SomethingWickedThisWayComes123456";

    REQUIRE(Execute(create_cmd) == 0); // Flaky!

    NativeFSManagerImpl fsm;
    auto predicate_old = [&]() -> bool {
        auto volumes = fsm.Volumes();
        return std::ranges::any_of(volumes,
                                   [&](const auto &volume) { return volume->mounted_at_path == volume_path_old; });
    };
    auto predicate_new = [&]() -> bool {
        auto volumes = fsm.Volumes();
        return std::ranges::any_of(volumes,
                                   [&](const auto &volume) { return volume->mounted_at_path == volume_path_new; });
    };
    REQUIRE(predicate_old() == false);
    REQUIRE(predicate_new() == false);

    REQUIRE(Execute(mount_cmd) == 0);
    auto unmount = at_scope_end([&] { Execute(unmount_cmd); });

    REQUIRE(runMainLoopUntilExpectationOrTimeout(10s, predicate_old));
    REQUIRE(predicate_new() == false);

    REQUIRE(Execute(rename_cmd) == 0);

    REQUIRE(runMainLoopUntilExpectationOrTimeout(10s, predicate_new));
    REQUIRE(predicate_old() == false);
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

static int Execute(const std::string &_command)
{
    using namespace boost::process;
    ipstream pipe_stream;
    child c(_command, std_out > pipe_stream);
    std::string line;
    while( c.running() && pipe_stream && std::getline(pipe_stream, line) && !line.empty() )
        ;
    c.wait();
    return c.exit_code();
}
