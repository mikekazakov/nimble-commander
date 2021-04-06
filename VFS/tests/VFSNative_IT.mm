// Copyright (C) 2020-2021 Michael Kazakov. Subject to GNU General Public License version 3.
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
    const auto dmg_path = tmp_dir.directory / "tmp_image.dmg";
    const auto create_cmd =
        "/usr/bin/hdiutil create -size 1m -fs HFS+ -volname SomethingWickedThisWayComes12345 " +
        dmg_path.native();
    const auto mount_cmd = "/usr/bin/hdiutil attach " + dmg_path.native();
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
    const auto dmg_path = tmp_dir.directory / "tmp_image.dmg";
    const auto bin = "/usr/bin/hdiutil";
    const auto create_args = std::vector<std::string>{"create",
                                                      "-size",
                                                      "1m",
                                                      "-fs",
                                                      "Case-sensitive HFS+",
                                                      "-volname",
                                                      "SomethingWickedThisWayComes12345",
                                                      dmg_path};
    const auto mount_cmd = "/usr/bin/hdiutil attach " + dmg_path.native();
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

TEST_CASE(PREFIX "SetFlags")
{
    TestDir dir;
    const auto host = TestEnv().vfs_native;
    struct ::stat st;
    SECTION("Regular file")
    {
        uint64_t vfs_flags = 0;
        SECTION("Flags::None") { vfs_flags = Flags::None; }
        SECTION("Flags::F_NoFollow") { vfs_flags = Flags::F_NoFollow; }
        const auto path = dir.directory / "regular_file";
        REQUIRE(close(creat(path.c_str(), 0755)) == 0);
        REQUIRE(host->SetFlags(path.c_str(), UF_HIDDEN, vfs_flags, nullptr) == VFSError::Ok);
        REQUIRE(::lstat(path.c_str(), &st) == 0);
        CHECK(st.st_flags & UF_HIDDEN);
    }
    SECTION("Symlink")
    {
        const auto path_reg = dir.directory / "regular_file";
        const auto path_sym = dir.directory / "symlink";
        REQUIRE(close(creat(path_reg.c_str(), 0755)) == 0);
        REQUIRE_NOTHROW(std::filesystem::create_symlink(path_reg, path_sym));
        SECTION("Flags::None")
        {
            REQUIRE(host->SetFlags(path_sym.c_str(), UF_HIDDEN, Flags::None, nullptr) ==
                    VFSError::Ok);
            REQUIRE(::lstat(path_sym.c_str(), &st) == 0);
            CHECK_FALSE(st.st_flags & UF_HIDDEN);
            REQUIRE(::lstat(path_reg.c_str(), &st) == 0);
            CHECK(st.st_flags & UF_HIDDEN);
        }
        SECTION("Flags::F_NoFollow")
        {
            REQUIRE(host->SetFlags(path_sym.c_str(), UF_HIDDEN, Flags::F_NoFollow, nullptr) ==
                    VFSError::Ok);
            REQUIRE(::lstat(path_sym.c_str(), &st) == 0);
            CHECK(st.st_flags & UF_HIDDEN);
            REQUIRE(::lstat(path_reg.c_str(), &st) == 0);
            CHECK_FALSE(st.st_flags & UF_HIDDEN);
        }
    }
    SECTION("Non-existent")
    {
        const auto path = dir.directory / "blah";
        CHECK(host->SetFlags(path.c_str(), UF_HIDDEN, Flags::None, nullptr) ==
              VFSError::FromErrno(ENOENT));
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
