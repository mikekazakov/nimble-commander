// Copyright (C) 2020-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../../source/Native/Fetching.h" // EVIL!
#include "TestEnv.h"
#include "Tests.h"
#include <Base/UnorderedUtil.h>
#include <Base/algo.h>
#include <Base/dispatch_cpp.h>
#include <algorithm>
#include <boost/process.hpp>
#include <fmt/core.h>
#include <fstream>
#include <unistd.h>

using namespace nc;
using namespace nc::vfs;
using namespace nc::vfs::native;
#define PREFIX "VFSNative "

static int Execute(const std::string &_command);
static int Execute(const std::string &_binary, const std::vector<std::string> &_args);
static bool RunMainLoopUntilExpectationOrTimeout(std::chrono::nanoseconds _timeout, std::function<bool()> _expectation);
static bool WaitUntilNativeFSManSeesVolumeAtPath(const std::filesystem::path &volume_path,
                                                 std::chrono::nanoseconds _time_limit);

TEST_CASE(PREFIX "Reports case-insensitive on directory path")
{
    const TestDir tmp_dir;
    const auto dmg_path = tmp_dir.directory / "tmp_image.dmg";
    const auto create_cmd = "/usr/bin/hdiutil create -size 1m -fs HFS+ -volname "
                            "SomethingWickedThisWayComes12345 " +
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
    const TestDir tmp_dir;
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
    const TestDir dir;
    const auto host = TestEnv().vfs_native;
    struct ::stat st;
    SECTION("Regular file")
    {
        uint64_t vfs_flags = 0;
        SECTION("Flags::None")
        {
            vfs_flags = Flags::None;
        }
        SECTION("Flags::F_NoFollow")
        {
            vfs_flags = Flags::F_NoFollow;
        }
        const auto path = dir.directory / "regular_file";
        REQUIRE(close(creat(path.c_str(), 0755)) == 0);
        REQUIRE(host->SetFlags(path.c_str(), UF_HIDDEN, vfs_flags, nullptr));
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
            REQUIRE(host->SetFlags(path_sym.c_str(), UF_HIDDEN, Flags::None, nullptr));
            REQUIRE(::lstat(path_sym.c_str(), &st) == 0);
            CHECK_FALSE(st.st_flags & UF_HIDDEN);
            REQUIRE(::lstat(path_reg.c_str(), &st) == 0);
            CHECK(st.st_flags & UF_HIDDEN);
        }
        SECTION("Flags::F_NoFollow")
        {
            REQUIRE(host->SetFlags(path_sym.c_str(), UF_HIDDEN, Flags::F_NoFollow, nullptr));
            REQUIRE(::lstat(path_sym.c_str(), &st) == 0);
            CHECK(st.st_flags & UF_HIDDEN);
            REQUIRE(::lstat(path_reg.c_str(), &st) == 0);
            CHECK_FALSE(st.st_flags & UF_HIDDEN);
        }
    }
    SECTION("Non-existent")
    {
        const auto path = dir.directory / "blah";
        CHECK(host->SetFlags(path.c_str(), UF_HIDDEN, Flags::None, nullptr).error() == Error{Error::POSIX, ENOENT});
    }
}

TEST_CASE(PREFIX "Fetching")
{
    const TestDir test_dir_holder;
    std::filesystem::path test_dir = test_dir_holder.directory;
    ankerl::unordered_dense::set<std::string, nc::UnorderedStringHashEqual, nc::UnorderedStringHashEqual> to_visit;
    const uid_t uid = geteuid();
    const uid_t gid = getgid();
    const time_t time = ::time(nullptr);
    const time_t time_eps = 100; // 100 seconds
    const dev_t dev = [&] {
        struct stat st;
        ::stat(test_dir.c_str(), &st);
        return st.st_dev;
    }();

    // spawn a bunch of regular files to ensure the batching mechanism can deal
    // with the mass
    for( size_t i = 0; i != 1000; ++i ) {
        auto filename = fmt::format("reg{}", i);
        REQUIRE(close(creat((test_dir / filename).c_str(), 0755)) == 0);
        to_visit.emplace(filename);
    }

    // spawn something with a size
    {
        std::ofstream(test_dir / "non-zero-reg-file") << "Hello, World!";
        to_visit.emplace("non-zero-reg-file");
    }

    // spawn a symlink
    {
        std::filesystem::create_symlink("/hello", test_dir / "symlink");
        to_visit.emplace("symlink");
    }

    // spawn a directory
    {
        std::filesystem::create_directory(test_dir / "directory");
        to_visit.emplace("directory");
    }

    // spawn a fifo
    {
        mkfifo((test_dir / "fifo").c_str(), 0644);
        to_visit.emplace("fifo");
    }

    // spawn a hidden file
    {
        REQUIRE(close(creat((test_dir / "hidden").c_str(), 0755)) == 0);
        chflags((test_dir / "hidden").c_str(), UF_HIDDEN);
        to_visit.emplace("hidden");
    }

    const size_t total_items_number = to_visit.size();

    const int fd = ::open(test_dir.c_str(), O_RDONLY | O_NONBLOCK | O_DIRECTORY | O_CLOEXEC);
    REQUIRE(fd > 0);
    auto close_fd = at_scope_end([fd] { close(fd); });

    size_t fetched_notification = 0;
    auto fetch = [&](size_t _fetched) { fetched_notification += _fetched; };
    auto param = [&](const Fetching::CallbackParams &p) {
        REQUIRE(p.filename != nullptr);
        const std::string_view filename(p.filename);
        REQUIRE(to_visit.contains(filename));
        to_visit.erase(to_visit.find(filename));

        // common checks for every file type
        CHECK(p.uid == uid);
        CHECK(p.gid == gid);
        CHECK(p.dev == dev);
        CHECK(p.inode != 0);

        // checks for specific file types
        if( filename.starts_with("reg") ) {
            CHECK(abs(p.crt_time - time) < time_eps);
            CHECK(abs(p.mod_time - time) < time_eps);
            CHECK(abs(p.chg_time - time) < time_eps);
            CHECK(abs(p.acc_time - time) < time_eps);
            CHECK((abs(p.add_time - time) < time_eps || p.add_time == -1)); // no add via ReadDirAttributesStat
            CHECK(p.mode == (S_IFREG | 0755));
            CHECK(p.size == 0);
            CHECK(p.flags == 0);
        }
        else if( filename == "non-zero-reg-file" ) {
            CHECK(p.size == std::string_view("Hello, World!").length());
        }
        else if( filename == "symlink" ) {
            CHECK(p.mode == (S_IFLNK | 0755));
            CHECK(p.size == std::string_view("/hello").length());
        }
        else if( filename == "directory" ) {
            CHECK(p.mode == (S_IFDIR | 0755));
        }
        else if( filename == "fifo" ) {
            CHECK(p.mode == (S_IFIFO | 0644));
        }
        else if( filename == "hidden" ) {
            CHECK(p.flags == UF_HIDDEN);
        }
        else {
            FAIL();
        }
    };

    SECTION("ReadDirAttributesStat")
    {
        CHECK(Fetching::ReadDirAttributesStat(fd, test_dir.c_str(), fetch, param) == 0);
    }
    SECTION("ReadDirAttributesBulk")
    {
        CHECK(Fetching::ReadDirAttributesBulk(fd, fetch, param) == 0);
    }

    CHECK(fetched_notification == total_items_number);
    CHECK(to_visit.empty());
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

static bool RunMainLoopUntilExpectationOrTimeout(std::chrono::nanoseconds _timeout, std::function<bool()> _expectation)
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
        return std::ranges::any_of(volumes,
                                   [volume_path](auto _fs_info) { return _fs_info->mounted_at_path == volume_path; });
    };
    return RunMainLoopUntilExpectationOrTimeout(_time_limit, predicate);
}
