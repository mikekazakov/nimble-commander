// Copyright (C) 2019-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include <Base/algo.h>
#include <Utility/TemporaryFileStorageImpl.h>
#include <Utility/PathManip.h>
#include <sys/stat.h>
#include <ftw.h>
#include <fstream>
#include <filesystem>

static int RMRF(const std::string &_path);
static auto g_TestDirPrefix = "_nc__vfs__easy_ops__test_";
static bool Save(const std::string &_filepath, const std::string &_content);
static std::string MakeTempFilesStorage();
#define PREFIX "[nc::vfs::easy] "

using nc::vfs::easy::CopyDirectoryToTempStorage;
using nc::vfs::easy::CopyFileToTempStorage;

TEST_CASE(PREFIX "CopyFileToTempStorage works")
{
    const auto base_dir = MakeTempFilesStorage();
    const auto remove_base_dir = at_scope_end([&] { RMRF(base_dir); });
    auto storage = nc::utility::TemporaryFileStorageImpl{base_dir, "some_prefix"};
    const auto content = "Hello, world!";
    Save(base_dir + "aaa.txt", content);
    auto host = TestEnv().vfs_native;

    const auto copied_path = CopyFileToTempStorage(base_dir + "aaa.txt", *host, storage);
    REQUIRE(copied_path != std::nullopt);
    CHECK(std::filesystem::path(*copied_path).filename() == "aaa.txt");

    CHECK(VFSEasyCompareFiles((base_dir + "aaa.txt").c_str(), host, (*copied_path).c_str(), host) == 0);
}

TEST_CASE(PREFIX "CopyDirectoryToTempStorage works")
{
    const auto base_dir = MakeTempFilesStorage();
    const auto remove_base_dir = at_scope_end([&] { RMRF(base_dir); });
    auto storage = nc::utility::TemporaryFileStorageImpl{base_dir, "some_prefix"};
    mkdir((base_dir + "A").c_str(), 0700);
    mkdir((base_dir + "A/B").c_str(), 0700);
    mkdir((base_dir + "A/C").c_str(), 0700);
    const auto content1 = "Hello, world!";
    const auto content2 = "Goodbye, world!";
    Save(base_dir + "A/B/aaa.txt", content1);
    Save(base_dir + "A/C/bbb.txt", content2);
    auto host = TestEnv().vfs_native;

    const auto copied_path =
        CopyDirectoryToTempStorage(base_dir + "A", *host, std::numeric_limits<uint64_t>::max(), storage);

    REQUIRE(copied_path != std::nullopt);
    CHECK(std::filesystem::path(*copied_path).parent_path().filename() == "A");
    CHECK(VFSEasyCompareFiles((base_dir + "A/B/aaa.txt").c_str(), host, (*copied_path + "B/aaa.txt").c_str(), host) ==
          0);
    CHECK(VFSEasyCompareFiles((base_dir + "A/C/bbb.txt").c_str(), host, (*copied_path + "C/bbb.txt").c_str(), host) ==
          0);
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
    const auto base_path = EnsureTrailingSlash(NSTemporaryDirectory().fileSystemRepresentation);
    const auto tmp_path = base_path + g_TestDirPrefix + "/";
    if( access(tmp_path.c_str(), F_OK) == 0 )
        RMRF(tmp_path);
    if( mkdir(tmp_path.c_str(), S_IRWXU) != 0 )
        throw std::runtime_error("mkdir failed");
    return tmp_path;
}

static bool Save(const std::string &_filepath, const std::string &_content)
{
    std::ofstream out(_filepath, std::ios::out | std::ios::binary);
    if( !out )
        return false;
    out << _content;
    out.close();
    return true;
}
