// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <Habanero/algo.h>
#include <Habanero/dispatch_cpp.h>
#include <boost/process.hpp>

using namespace nc::vfs;
#define PREFIX "VFSNative "

static int Execute(const std::string &_command);
static int Execute(const std::string &_binary, const std::vector<std::string> &_args);
static bool RunMainLoopUntilExpectationOrTimeout(std::chrono::nanoseconds _timeout,
                                                 std::function<bool()> _expectation);
static bool WaitUntilNativeFSManSeesVolumeAtPath(const std::filesystem::path &volume_path,
                                                 std::chrono::nanoseconds _time_limit);

TEST_CASE(PREFIX "Reports case-insensitive on directory path")
{
    TestDir tmp_dir;
    const auto dmg_path = tmp_dir.directory + "tmp_image.dmg";
    const auto create_cmd =
        "/usr/bin/hdiutil create -size 1m -fs HFS+ -volname SomethingWickedThisWayComes12345 " +
        dmg_path;
    const auto mount_cmd = "/usr/bin/hdiutil attach " + dmg_path;
    const auto unmount_cmd = "/usr/bin/hdiutil detach /Volumes/SomethingWickedThisWayComes12345";
    const std::filesystem::path volume_path = "/Volumes/SomethingWickedThisWayComes12345";
    REQUIRE(Execute(create_cmd) == 0);
    REQUIRE(Execute(mount_cmd) == 0);
    const auto unmount = at_scope_end([&] { Execute(unmount_cmd); });
    REQUIRE(mkdir((volume_path / "Dir1").c_str(), 0755) == 0);
    REQUIRE(mkdir((volume_path / "Dir1/Dir2").c_str(), 0755) == 0);
    REQUIRE(close(creat((volume_path / "Dir1/Dir2/reg").c_str(), 0755)) == 0);
    WaitUntilNativeFSManSeesVolumeAtPath(volume_path, std::chrono::seconds(5));

    auto &vfs = *TestEnv().vfs_native;
    CHECK(vfs.IsCaseSensitiveAtPath(volume_path.c_str()) == false);
    CHECK(vfs.IsCaseSensitiveAtPath((volume_path / "Dir1").c_str()) == false);
    CHECK(vfs.IsCaseSensitiveAtPath((volume_path / "Dir1/Dir2").c_str()) == false);
    CHECK(vfs.IsCaseSensitiveAtPath((volume_path / "Dir1/Dir2/reg").c_str()) == false);
}

TEST_CASE(PREFIX "Reports case-sensitive on directory path")
{
    TestDir tmp_dir;
    const auto dmg_path = tmp_dir.directory + "tmp_image.dmg";
    const auto bin = "/usr/bin/hdiutil";
    const auto create_args = std::vector<std::string>{"create",
                                                      "-size",
                                                      "1m",
                                                      "-fs",
                                                      "Case-sensitive HFS+",
                                                      "-volname",
                                                      "SomethingWickedThisWayComes12345",
                                                      dmg_path};
    const auto mount_cmd = "/usr/bin/hdiutil attach " + dmg_path;
    const auto unmount_cmd = "/usr/bin/hdiutil detach /Volumes/SomethingWickedThisWayComes12345";
    const std::filesystem::path volume_path = "/Volumes/SomethingWickedThisWayComes12345";
    REQUIRE(Execute(bin, create_args) == 0);
    REQUIRE(Execute(mount_cmd) == 0);
    const auto unmount = at_scope_end([&] { Execute(unmount_cmd); });
    REQUIRE(mkdir((volume_path / "Dir1").c_str(), 0755) == 0);
    REQUIRE(mkdir((volume_path / "Dir1/Dir2").c_str(), 0755) == 0);
    REQUIRE(close(creat((volume_path / "Dir1/Dir2/reg").c_str(), 0755)) == 0);
    WaitUntilNativeFSManSeesVolumeAtPath(volume_path, std::chrono::seconds(5));

    auto &vfs = *TestEnv().vfs_native;
    CHECK(vfs.IsCaseSensitiveAtPath(volume_path.c_str()) == true);
    CHECK(vfs.IsCaseSensitiveAtPath((volume_path / "Dir1").c_str()) == true);
    CHECK(vfs.IsCaseSensitiveAtPath((volume_path / "Dir1/Dir2").c_str()) == true);
    CHECK(vfs.IsCaseSensitiveAtPath((volume_path / "Dir1/Dir2/reg").c_str()) == true);
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

static int Execute(const std::string &_binary, const std::vector<std::string> &_args)
{
    using namespace boost::process;
    ipstream pipe_stream;
    child c(_binary, _args, std_out > pipe_stream);
    std::string line;
    while( c.running() && pipe_stream && std::getline(pipe_stream, line) && !line.empty() )
        ;
    c.wait();
    return c.exit_code();
}

static bool RunMainLoopUntilExpectationOrTimeout(std::chrono::nanoseconds _timeout,
                                                 std::function<bool()> _expectation)
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

static bool WaitUntilNativeFSManSeesVolumeAtPath(const std::filesystem::path &volume_path,
                                                 std::chrono::nanoseconds _time_limit)
{
    auto predicate = [volume_path] {
        auto volumes = TestEnv().native_fs_man->Volumes();
        return std::any_of(volumes.begin(), volumes.end(), [volume_path](auto _fs_info) {
            return _fs_info->mounted_at_path == volume_path;
        });
    };
    return RunMainLoopUntilExpectationOrTimeout(_time_limit, predicate);
}
