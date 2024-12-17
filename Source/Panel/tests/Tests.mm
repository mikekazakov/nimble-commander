// Copyright (C) 2020-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#define CATCH_CONFIG_ENABLE_BENCHMARKING
#include <catch2/catch_all.hpp>
#include <Base/CommonPaths.h>
#include <Utility/FSEventsFileUpdateImpl.h>
#include <Utility/NativeFSManagerImpl.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <sys/dirent.h>
#include <ftw.h>
#include <memory>
#include "Tests.h"

static auto g_TestDirPrefix = "_nc__panel__test_";

int main(int argc, char *argv[])
{
    const int result = Catch::Session().run(argc, argv);
    return result;
}

static int RMRF(const std::string &_path)
{
    auto unlink_cb = [](const char *fpath,
                        [[maybe_unused]] const struct stat *sb,
                        int typeflag,
                        [[maybe_unused]] struct FTW *ftwbuf) {
        if( typeflag == FTW_F )
            unlink(fpath);
        else if( typeflag == FTW_D || typeflag == FTW_DNR || typeflag == FTW_DP )
            rmdir(fpath);
        return 0;
    };
    return nftw(_path.c_str(), unlink_cb, 64, FTW_DEPTH | FTW_PHYS | FTW_MOUNT);
}

static std::string MakeTempFilesStorage()
{
    const auto base_path = nc::base::CommonPaths::AppTemporaryDirectory();
    const auto tmp_path = base_path + g_TestDirPrefix + "/";
    if( access(tmp_path.c_str(), F_OK) == 0 )
        RMRF(tmp_path);
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
    RMRF(directory);
}

const TestEnvironment &TestEnv() noexcept
{
    [[clang::no_destroy]] static const std::unique_ptr<TestEnvironment> env = [] {
        auto e = std::make_unique<TestEnvironment>();
        e->fsevents_file_update = std::make_shared<nc::utility::FSEventsFileUpdateImpl>();
        e->native_fs_man = std::make_shared<nc::utility::NativeFSManagerImpl>();
        e->vfs_native = std::make_shared<nc::vfs::NativeHost>(*e->native_fs_man, *e->fsevents_file_update);
        return e;
    }();
    return *env;
}
