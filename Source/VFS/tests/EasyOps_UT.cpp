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

#define PREFIX "[nc::vfs::easy] "

namespace EasyTests {

static bool Save(const std::string &_filepath, const std::string &_content);

using nc::vfs::easy::CopyDirectoryToTempStorage;
using nc::vfs::easy::CopyFileToTempStorage;
using nc::vfs::easy::VFSEasyCompareFiles;

TEST_CASE(PREFIX "CopyFileToTempStorage works")
{
    const TestDir test_dir;
    auto storage = nc::utility::TemporaryFileStorageImpl{test_dir.directory.native(), "some_prefix"};
    const auto content = "Hello, world!";
    Save(test_dir.directory / "aaa.txt", content);
    auto host = TestEnv().vfs_native;

    const auto copied_path = CopyFileToTempStorage(test_dir.directory / "aaa.txt", *host, storage);
    REQUIRE(copied_path != std::nullopt);
    CHECK(std::filesystem::path(*copied_path).filename() == "aaa.txt");

    CHECK(VFSEasyCompareFiles((test_dir.directory / "aaa.txt").c_str(), host, (*copied_path).c_str(), host) == 0);
}

TEST_CASE(PREFIX "CopyDirectoryToTempStorage works")
{
    const TestDir test_dir;
    auto storage = nc::utility::TemporaryFileStorageImpl{test_dir.directory.native(), "some_prefix"};
    mkdir((test_dir.directory / "A").c_str(), 0700);
    mkdir((test_dir.directory / "A/B").c_str(), 0700);
    mkdir((test_dir.directory / "A/C").c_str(), 0700);
    const auto content1 = "Hello, world!";
    const auto content2 = "Goodbye, world!";
    Save(test_dir.directory / "A/B/aaa.txt", content1);
    Save(test_dir.directory / "A/C/bbb.txt", content2);
    auto host = TestEnv().vfs_native;

    const auto copied_path =
        CopyDirectoryToTempStorage(test_dir.directory / "A", *host, std::numeric_limits<uint64_t>::max(), storage);

    REQUIRE(copied_path != std::nullopt);
    CHECK(std::filesystem::path(*copied_path).parent_path().filename() == "A");
    CHECK(VFSEasyCompareFiles(
              (test_dir.directory / "A/B/aaa.txt").c_str(), host, (*copied_path / "B/aaa.txt").c_str(), host) == 0);
    CHECK(VFSEasyCompareFiles(
              (test_dir.directory / "A/C/bbb.txt").c_str(), host, (*copied_path / "C/bbb.txt").c_str(), host) == 0);
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

} // namespace EasyTests

#undef PREFIX
