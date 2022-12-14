// Copyright (C) 2018-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#define CATCH_CONFIG_RUNNER
#define CATCH_CONFIG_ENABLE_BENCHMARKING
#include <catch2/catch.hpp>

#define GTEST_DONT_DEFINE_FAIL 1
#define GTEST_DONT_DEFINE_SUCCEED 1
#include <gmock/gmock.h>

#include "Tests.h"
#include <Habanero/CommonPaths.h>
#include <ftw.h>

static auto g_TestDirPrefix = "_nc__vfs__test_";

int main( int argc, char* argv[] ) {
    ::testing::GTEST_FLAG(throw_on_failure) = true;
    ::testing::InitGoogleMock(&argc, argv);
    int result = Catch::Session().run( argc, argv );
    return result;
}

TestDir::TestDir()
{
    directory = MakeTempFilesStorage();
}

TestDir::~TestDir()
{
    std::filesystem::remove_all(directory);
}

std::string TestDir::MakeTempFilesStorage()
{
    const auto base_path = nc::base::CommonPaths::AppTemporaryDirectory();
    const auto tmp_path = base_path + g_TestDirPrefix + "/";
    if( access(tmp_path.c_str(), F_OK) == 0 )
        std::filesystem::remove_all(tmp_path);
    if( mkdir(tmp_path.c_str(), S_IRWXU) != 0 )
        throw std::runtime_error("mkdir failed");
    return tmp_path;
}
