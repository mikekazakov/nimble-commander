// Copyright (C) 2020-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <catch2/catch_all.hpp>
#include <Base/CommonPaths.h>
#include <Base/ExecutionDeadline.h>
#include <Base/debug.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <sys/dirent.h>
#include "Tests.h"
#include <Log.h>
#include <spdlog/sinks/stdout_sinks.h>
#include <spdlog/sinks/ringbuffer_sink.h>
#include <iostream>

using namespace nc::term;

static auto g_TestDirPrefix = "_nc__term__test_";
[[clang::no_destroy]] static auto g_LogSink = std::make_shared<spdlog::sinks::ringbuffer_sink_mt>(1000);
[[clang::no_destroy]] static auto g_Log = std::make_shared<spdlog::logger>("term", g_LogSink);

static void DumpLog()
{
    std::cout << "Last log entries, up to 100:" << '\n';
    for( auto &line : g_LogSink->last_formatted(1000) )
        std::cout << line;
    std::cout << '\n';
}

struct CatchEventsListener : Catch::EventListenerBase {
    using EventListenerBase::EventListenerBase; // inherit constructor
    void assertionEnded(const Catch::AssertionStats &stats) override
    {
        if( !stats.assertionResult.isOk() ) {
            DumpLog();
        }
    }
};
CATCH_REGISTER_LISTENER(CatchEventsListener);

int main(int argc, char *argv[])
{
    const nc::base::ExecutionDeadline deadline(nc::base::AmIBeingDebugged() ? std::chrono::hours(1)
                                                                            : std::chrono::minutes(1));
    g_Log->set_level(spdlog::level::debug);
    Log::Set(g_Log);
    const int result = Catch::Session().run(argc, argv);
    return result;
}

static std::string MakeTempFilesStorage()
{
    const auto base_path = nc::base::CommonPaths::AppTemporaryDirectory();
    const auto tmp_path = base_path + g_TestDirPrefix + "/";
    if( std::filesystem::exists(tmp_path) )
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
    std::filesystem::remove_all(directory);
}
