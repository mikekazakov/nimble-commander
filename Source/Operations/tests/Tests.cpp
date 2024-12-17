// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <algorithm>
#include <catch2/catch_all.hpp>

#define GTEST_DONT_DEFINE_FAIL 1
#define GTEST_DONT_DEFINE_SUCCEED 1
#include <gmock/gmock.h>

#include "Tests.h"
#include "TestEnv.h"
#include <Base/CommonPaths.h>
#include <Base/dispatch_cpp.h>
#include <boost/process.hpp>

#include <spdlog/sinks/stdout_sinks.h>
#include <VFS/Log.h>

static auto g_TestDirPrefix = "_nc__operations__test_";

[[clang::no_destroy]] static auto g_LogSink = std::make_shared<spdlog::sinks::stdout_sink_mt>();
[[clang::no_destroy]] static auto g_Log = std::make_shared<spdlog::logger>("vfs", g_LogSink);

static int Execute(const std::string &_command);
static bool RunMainLoopUntilExpectationOrTimeout(std::chrono::nanoseconds _timeout, std::function<bool()> _expectation);
static bool WaitUntilNativeFSManSeesVolumeAtPath(const std::filesystem::path &volume_path,
                                                 std::chrono::nanoseconds _time_limit);

int main(int argc, char *argv[])
{
    //    g_Log->set_level(spdlog::level::trace);
    //    nc::vfs::Log::Set(g_Log);

    ::testing::GTEST_FLAG(throw_on_failure) = true;
    ::testing::InitGoogleMock(&argc, argv);
    const int result = Catch::Session().run(argc, argv);
    return result;
}

static std::string MakeTempFilesStorage()
{
    const auto base_path = nc::base::CommonPaths::AppTemporaryDirectory();
    const auto tmp_path = base_path + g_TestDirPrefix + "/";
    if( access(tmp_path.c_str(), F_OK) == 0 )
        std::filesystem::remove_all(tmp_path);
    if( mkdir(tmp_path.c_str(), S_IRWXU) != 0 )
        throw std::runtime_error("mkdir failed");
    return tmp_path;
}

TempTestDir::TempTestDir()
{
    directory = MakeTempFilesStorage();
}

TempTestDir::~TempTestDir()
{
    try {
        std::filesystem::remove_all(directory);
    } catch( const std::exception &ex ) {
        std::cerr << ex.what() << '\n';
    }
}

TempTestDmg::TempTestDmg(TempTestDir &_test_dir)
{
    const auto dmg_path = _test_dir.directory / "tmp_image.dmg";
    const auto create_cmd =
        "/usr/bin/hdiutil create -size 1m -fs HFS+ -volname SomethingWickedThisWayComes12345 " + dmg_path.native();
    const auto mount_cmd = "/usr/bin/hdiutil attach " + dmg_path.native();

    REQUIRE(Execute(create_cmd) == 0);
    REQUIRE(Execute(mount_cmd) == 0);

    directory = "/Volumes/SomethingWickedThisWayComes12345";
    REQUIRE(WaitUntilNativeFSManSeesVolumeAtPath(directory, std::chrono::seconds(5)));
}

TempTestDmg::~TempTestDmg()
{
    const auto unmount_cmd = "/usr/bin/hdiutil detach /Volumes/SomethingWickedThisWayComes12345";
    Execute(unmount_cmd);
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
