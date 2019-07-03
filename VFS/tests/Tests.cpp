// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#define CATCH_CONFIG_RUNNER
#include <catch2/catch.hpp>

#define GTEST_DONT_DEFINE_FAIL 1
#define GTEST_DONT_DEFINE_SUCCEED 1
#include <gmock/gmock.h>

#include "Tests.h"
#include <Habanero/CommonPaths.h>

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
    RMRF(directory);
}

int TestDir::RMRF(const std::string& _path)
{
    auto unlink_cb = [](const char *fpath,
                        [[maybe_unused]] const struct stat *sb,
                        int typeflag,
                        [[maybe_unused]] struct FTW *ftwbuf) {
        if( typeflag == FTW_F)
            unlink(fpath);
        else if( typeflag == FTW_D   ||
                typeflag == FTW_DNR ||
                typeflag == FTW_DP   )
            rmdir(fpath);
        return 0;
    };
    return nftw(_path.c_str(), unlink_cb, 64, FTW_DEPTH | FTW_PHYS | FTW_MOUNT);
}

std::string TestDir::MakeTempFilesStorage()
{
    const auto base_path = CommonPaths::AppTemporaryDirectory();
    const auto tmp_path = base_path + g_TestDirPrefix + "/";
    if( access(tmp_path.c_str(), F_OK) == 0 )
        RMRF(tmp_path);
    if( mkdir(tmp_path.c_str(), S_IRWXU) != 0 )
        throw std::runtime_error("mkdir failed");
    return tmp_path;
}
