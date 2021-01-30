// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#define CATCH_CONFIG_RUNNER
#include <catch2/catch.hpp>
#include <Habanero/CommonPaths.h>
#include <Habanero/ExecutionDeadline.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <sys/dirent.h>
#include "Tests.h"
#include <Log.h>
#include <spdlog/sinks/stdout_sinks.h>
#include <spdlog/sinks/ringbuffer_sink.h>

using namespace nc::term;

static auto g_TestDirPrefix = "_nc__term__test_";
[[clang::no_destroy]] static auto g_LogSink =
    std::make_shared<spdlog::sinks::ringbuffer_sink_mt>(1000);
[[clang::no_destroy]] static auto g_Log = std::make_shared<spdlog::logger>(Log::Name(), g_LogSink);

static void DumpLog()
{
    std::cout << "Last log entries, up to 100:" << std::endl;
    for( auto &line : g_LogSink->last_formatted(1000) )
        std::cout << line;
    std::cout << std::endl;
}

struct CatchEventsListener : Catch::TestEventListenerBase {
    using TestEventListenerBase::TestEventListenerBase; // inherit constructor
    bool assertionEnded(Catch::AssertionStats const &stats) override
    {
        if( !stats.assertionResult.isOk() ) {
            DumpLog();
        }
        return true;
    }
};
CATCH_REGISTER_LISTENER(CatchEventsListener);

int main(int argc, char *argv[])
{
    nc::base::ExecutionDeadline deadline(std::chrono::minutes(1));
    g_Log->set_level(spdlog::level::debug);
    Log::Set(g_Log);
    int result = Catch::Session().run(argc, argv);
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
    std::filesystem::remove_all(directory);
}
