// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <Operations/Copying.h>
#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include <VFS/XAttr.h>
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <VFS/ArcLA.h>
#include <Base/algo.h>
#include <Base/WriteAtomically.h>
#include <set>
#include <span>
#include <fstream>
#include <compare>
#include <thread>
#include <condition_variable>

using nc::Error;
using nc::ops::Copying;
using nc::ops::CopyingOptions;
using nc::ops::OperationState;

static std::vector<std::byte> MakeNoise(size_t _size);
static bool Save(const std::filesystem::path &_filepath, std::span<const std::byte> _content);
static std::expected<int, Error> VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                                                   const VFSHostPtr &_file1_host,
                                                   const std::filesystem::path &_file2_full_path,
                                                   const VFSHostPtr &_file2_host);
static std::vector<VFSListingItem>
FetchItems(const std::string &_directory_path, const std::vector<std::string> &_filenames, VFSHost &_host)
{
    return _host.FetchFlexibleListingItems(_directory_path, _filenames, 0).value_or(std::vector<VFSListingItem>{});
}

#define PREFIX "nc::ops::Copying "

static void RunOperationAndCheckSuccess(nc::ops::Operation &operation)
{
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
}

TEST_CASE(PREFIX "Verify that /Applications/ and temp dir are on the same fs")
{
    const std::string target_dir = "/Applications/";
    const TempTestDir test_dir;
    REQUIRE(TestEnv().native_fs_man->VolumeFromPath(test_dir.directory.native()) ==
            TestEnv().native_fs_man->VolumeFromPath(target_dir));
}

TEST_CASE(PREFIX "Can rename a regular file across firmlink injection points")
{
    const std::string filename = "__nc_rename_test__";
    const std::string target_dir = "/Applications/";
    auto rm_result = [&] { unlink((target_dir + filename).c_str()); };
    rm_result();
    auto clean_afterward = at_scope_end([&] { rm_result(); });

    const TempTestDir test_dir;

    REQUIRE(close(creat((test_dir.directory / filename).c_str(), 0755)) == 0);

    struct stat orig_stat;
    REQUIRE(stat((test_dir.directory / filename).c_str(), &orig_stat) == 0);

    CopyingOptions opts;
    opts.docopy = false;

    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename}, *host), target_dir, host, opts);
    RunOperationAndCheckSuccess(op);

    struct stat renamed_stat;
    REQUIRE(stat((target_dir + filename).c_str(), &renamed_stat) == 0);

    // Verify that the file was renamed instead of copied+deleted
    CHECK(renamed_stat.st_dev == orig_stat.st_dev);
    CHECK(renamed_stat.st_ino == orig_stat.st_ino);
}

TEST_CASE(PREFIX "Can rename a directory across firmlink injection points")
{
    const std::string filename = "__nc_rename_test__";
    const std::string target_dir = "/Applications/";
    auto rm_result = [&] { rmdir((target_dir + filename).c_str()); };
    rm_result();
    auto clean_afterward = at_scope_end([&] { rm_result(); });

    const TempTestDir test_dir;

    REQUIRE(mkdir((test_dir.directory / filename).c_str(), 0755) == 0);

    struct stat orig_stat;
    REQUIRE(stat((test_dir.directory / filename).c_str(), &orig_stat) == 0);

    CopyingOptions opts;
    opts.docopy = false;

    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename}, *host), target_dir, host, opts);
    RunOperationAndCheckSuccess(op);

    struct stat renamed_stat;
    REQUIRE(stat((target_dir + filename).c_str(), &renamed_stat) == 0);

    // Verify that the directory was renamed instead of copied+deleted
    CHECK(renamed_stat.st_dev == orig_stat.st_dev);
    CHECK(renamed_stat.st_ino == orig_stat.st_ino);
}

TEST_CASE(PREFIX "Can rename a non-empty directory across firmlink injection points")
{
    const std::string filename = "__nc_rename_test__";
    const std::string filename_in_dir = "filename.txt";
    const std::string target_dir = "/Applications/";
    auto rm_result = [&] {
        unlink((target_dir + filename + "/" + filename_in_dir).c_str());
        rmdir((target_dir + filename).c_str());
    };
    rm_result();
    auto clean_afterward = at_scope_end([&] { rm_result(); });

    const TempTestDir test_dir;

    REQUIRE(mkdir((test_dir.directory / filename).c_str(), 0755) == 0);
    REQUIRE(close(creat((test_dir.directory / filename / filename_in_dir).c_str(), 0755)) == 0);

    struct stat orig_stat;
    REQUIRE(stat((test_dir.directory / filename).c_str(), &orig_stat) == 0);

    CopyingOptions opts;
    opts.docopy = false;

    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename}, *host), target_dir, host, opts);
    RunOperationAndCheckSuccess(op);

    struct stat renamed_stat;
    REQUIRE(stat((target_dir + filename).c_str(), &renamed_stat) == 0);

    // Verify that the directory was renamed instead of copied+deleted
    CHECK(renamed_stat.st_dev == orig_stat.st_dev);
    CHECK(renamed_stat.st_ino == orig_stat.st_ino);
}

TEST_CASE(PREFIX "Can rename a symlink across firmlink injection points")
{
    const std::string filename = "__nc_rename_test__";
    const std::string target_dir = "/Applications/";
    auto rm_result = [&] { unlink((target_dir + filename).c_str()); };
    rm_result();
    auto clean_afterward = at_scope_end([&] { rm_result(); });

    const TempTestDir test_dir;

    REQUIRE(symlink("/", (test_dir.directory / filename).c_str()) == 0);

    struct stat orig_stat;
    REQUIRE(lstat((test_dir.directory / filename).c_str(), &orig_stat) == 0);

    CopyingOptions opts;
    opts.docopy = false;

    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename}, *host), target_dir, host, opts);
    RunOperationAndCheckSuccess(op);

    struct stat renamed_stat;
    REQUIRE(lstat((target_dir + filename).c_str(), &renamed_stat) == 0);

    // Verify that the directory was renamed instead of copied+deleted
    CHECK(renamed_stat.st_dev == orig_stat.st_dev);
    CHECK(renamed_stat.st_ino == orig_stat.st_ino);
}

TEST_CASE(PREFIX "Can rename a regular file on injected data volume")
{
    const std::string filename_src = "__nc_rename_test__";
    const std::string filename_dst = "__nc_rename_test__2";
    const std::string target_dir = "/Applications/";
    auto rm_result = [&] {
        unlink((target_dir + filename_src).c_str());
        unlink((target_dir + filename_dst).c_str());
    };
    rm_result();
    auto clean_afterward = at_scope_end([&] { rm_result(); });

    const TempTestDir test_dir;

    REQUIRE(close(creat((test_dir.directory / filename_src).c_str(), 0755)) == 0);

    struct stat orig_stat;
    REQUIRE(stat((test_dir.directory / filename_src).c_str(), &orig_stat) == 0);

    CopyingOptions opts;
    opts.docopy = false;

    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename_src}, *host), target_dir + filename_dst, host, opts);
    RunOperationAndCheckSuccess(op);

    struct stat renamed_stat;
    REQUIRE(stat((target_dir + filename_dst).c_str(), &renamed_stat) == 0);

    // Verify that the file was renamed instead of copied+deleted
    CHECK(renamed_stat.st_dev == orig_stat.st_dev);
    CHECK(renamed_stat.st_ino == orig_stat.st_ino);
}

TEST_CASE(PREFIX "Correctly handles requests to rename into non-existing dir")
{
    const std::string filename = "__nc_rename_test__";
    const std::string target_dir = "a/b/c/d/";

    const TempTestDir test_dir;

    REQUIRE(close(creat((test_dir.directory / filename).c_str(), 0755)) == 0);

    struct stat orig_stat;
    REQUIRE(stat((test_dir.directory / filename).c_str(), &orig_stat) == 0);

    CopyingOptions opts;
    opts.docopy = false;

    auto host = TestEnv().vfs_native;
    Copying op(
        FetchItems(test_dir.directory, {filename}, *host), test_dir.directory / target_dir / filename, host, opts);
    RunOperationAndCheckSuccess(op);

    struct stat renamed_stat;
    REQUIRE(stat((test_dir.directory / target_dir / filename).c_str(), &renamed_stat) == 0);

    // Verify that the file was renamed instead of copied+deleted
    CHECK(renamed_stat.st_dev == orig_stat.st_dev);
    CHECK(renamed_stat.st_ino == orig_stat.st_ino);
}

TEST_CASE(PREFIX "Reports item status")
{
    const TempTestDir test_dir;
    REQUIRE(mkdir((test_dir.directory / "A").c_str(), 0755) == 0);
    REQUIRE(close(creat((test_dir.directory / "A/f1").c_str(), 0755)) == 0);
    REQUIRE(close(creat((test_dir.directory / "A/f2").c_str(), 0755)) == 0);

    auto host = TestEnv().vfs_native;
    std::set<std::string> processed;
    Copying op(FetchItems(test_dir.directory, {"A"}, *host), test_dir.directory / "B", host, {});
    op.SetItemStatusCallback([&](nc::ops::ItemStateReport _report) {
        REQUIRE(&_report.host == host.get());
        REQUIRE(_report.status == nc::ops::ItemStatus::Processed);
        processed.emplace(_report.path);
    });
    RunOperationAndCheckSuccess(op);

    const std::set<std::string> expected{
        test_dir.directory / "A", test_dir.directory / "A/f1", test_dir.directory / "A/f2"};
    CHECK(processed == expected);
}

TEST_CASE(PREFIX "Overwrite bug regression")
{
    // ensures no-return of a bug introduced 30/01/15
    const TempTestDir tmp_dir;
    const auto dest = tmp_dir.directory / "dest.zzz";
    const auto host = TestEnv().vfs_native;
    const size_t size_big = 54598243;
    const size_t size_small = 54594493;
    const auto data_big = MakeNoise(size_big);
    const auto data_small = MakeNoise(size_small);
    REQUIRE(Save(tmp_dir.directory / "big.zzz", data_big));
    REQUIRE(Save(tmp_dir.directory / "small.zzz", data_small));

    {
        CopyingOptions opts;
        opts.docopy = true;
        Copying op(FetchItems(tmp_dir.directory, {"big.zzz"}, *host), dest, host, opts);
        op.Start();
        op.Wait();
    }

    REQUIRE(VFSEasyCompareFiles((tmp_dir.directory / "big.zzz").c_str(), host, dest.c_str(), host) == 0);

    {
        CopyingOptions opts;
        opts.docopy = true;
        opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
        Copying op(FetchItems(tmp_dir.directory, {"small.zzz"}, *host), dest, host, opts);
        op.Start();
        op.Wait();
    }

    REQUIRE(VFSEasyCompareFiles((tmp_dir.directory / "small.zzz").c_str(), host, dest.c_str(), host) == 0);
}

TEST_CASE(PREFIX "Overwrite bug regression - revert")
{
    // ensures no-return of a bug introduced 30/01/15
    const TempTestDir tmp_dir;
    const auto dest = tmp_dir.directory / "dest.zzz";
    const auto host = TestEnv().vfs_native;
    const size_t size_big = 54598243;
    const size_t size_small = 54594493;
    const auto data_big = MakeNoise(size_big);
    const auto data_small = MakeNoise(size_small);
    REQUIRE(Save(tmp_dir.directory / "big.zzz", data_big));
    REQUIRE(Save(tmp_dir.directory / "small.zzz", data_small));

    {
        CopyingOptions opts;
        opts.docopy = true;
        Copying op(FetchItems(tmp_dir.directory, {"small.zzz"}, *host), dest, host, opts);
        op.Start();
        op.Wait();
    }

    REQUIRE(VFSEasyCompareFiles((tmp_dir.directory / "small.zzz").c_str(), host, dest.c_str(), host) == 0);

    {
        CopyingOptions opts;
        opts.docopy = true;
        opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
        Copying op(FetchItems(tmp_dir.directory, {"big.zzz"}, *host), dest, host, opts);
        op.Start();
        op.Wait();
    }

    REQUIRE(VFSEasyCompareFiles((tmp_dir.directory / "big.zzz").c_str(), host, dest.c_str(), host) == 0);
}

TEST_CASE(PREFIX "case renaming")
{
    const TempTestDir tmp_dir;
    const auto host = TestEnv().vfs_native;
    const auto dir = tmp_dir.directory;

    {
        const auto src = dir / "directory";
        mkdir(src.c_str(), S_IWUSR | S_IXUSR | S_IRUSR);

        CopyingOptions opts;
        opts.docopy = false;
        Copying op(FetchItems(dir.native(), {"directory"}, *host), (dir / "DIRECTORY").native(), host, opts);
        op.Start();
        op.Wait();

        REQUIRE(host->IsDirectory((dir / "DIRECTORY").c_str(), 0, nullptr) == true);
        REQUIRE(FetchItems(dir.native(), {"DIRECTORY"}, *host).front().Filename() == "DIRECTORY");
    }

    {
        auto src = dir / "filename";
        close(open(src.c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));

        CopyingOptions opts;
        opts.docopy = false;
        Copying op(FetchItems(dir.native(), {"filename"}, *host), (dir / "FILENAME").native(), host, opts);

        op.Start();
        op.Wait();

        REQUIRE(host->Exists((dir / "FILENAME").c_str()) == true);
        REQUIRE(FetchItems(dir.native(), {"FILENAME"}, *host).front().Filename() == "FILENAME");
    }
}

TEST_CASE(PREFIX "Modes - CopyToPrefix")
{
    const TempTestDir tmp_dir;
    const auto host = TestEnv().vfs_native;
    const CopyingOptions opts;
    Copying op(FetchItems("/System/Applications/", {"Mail.app"}, *TestEnv().vfs_native), tmp_dir.directory, host, opts);

    op.Start();
    op.Wait();

    REQUIRE(VFSCompareEntries(std::filesystem::path("/System/Applications") / "Mail.app",
                              TestEnv().vfs_native,
                              tmp_dir.directory / "Mail.app",
                              TestEnv().vfs_native) == 0);
}

TEST_CASE(PREFIX "Modes - CopyToPrefix, with absent directories in path")
{
    const TempTestDir tmp_dir;
    const auto host = TestEnv().vfs_native;

    // just like above, but file copy operation should build a destination path
    const auto dst_dir = tmp_dir.directory / "Some" / "Absent" / "Dir" / "Is" / "Here/";

    const CopyingOptions opts;
    Copying op(FetchItems("/System/Applications/", {"Mail.app"}, *TestEnv().vfs_native), dst_dir.native(), host, opts);

    op.Start();
    op.Wait();

    REQUIRE(VFSCompareEntries(std::filesystem::path("/System/Applications") / "Mail.app",
                              TestEnv().vfs_native,
                              dst_dir / "Mail.app",
                              TestEnv().vfs_native) == 0);
}

// this test is now actually outdated, since FileCopyOperation now requires that destination path is
// absolute
TEST_CASE(PREFIX "Modes - CopyToPrefix_WithLocalDir")
{
    const TempTestDir tmp_dir;
    auto host = TestEnv().vfs_native;

    REQUIRE(VFSEasyCopyNode("/System/Applications/Mail.app", host, (tmp_dir.directory / "Mail.app").c_str(), host) ==
            0);

    const CopyingOptions opts;
    Copying op(FetchItems(tmp_dir.directory, {"Mail.app"}, *TestEnv().vfs_native),
               tmp_dir.directory / "SomeDirectoryName/",
               host,
               opts);

    op.Start();
    op.Wait();

    REQUIRE(VFSCompareEntries(
                "/System/Applications/Mail.app", host, tmp_dir.directory / "SomeDirectoryName" / "Mail.app", host) ==
            0);
}

// this test is now somewhat outdated, since FileCopyOperation now requires that destination path is
// absolute
TEST_CASE(PREFIX "Modes - CopyToPathName_WithLocalDir")
{
    // Copies "Mail.app" to "Mail2.app" in the same dir
    const TempTestDir tmp_dir;
    auto host = TestEnv().vfs_native;

    REQUIRE(VFSEasyCopyNode("/System/Applications/Mail.app", host, (tmp_dir.directory / "Mail.app").c_str(), host) ==
            0);

    Copying op(
        FetchItems(tmp_dir.directory, {"Mail.app"}, *TestEnv().vfs_native), tmp_dir.directory / "Mail2.app", host, {});

    op.Start();
    op.Wait();

    REQUIRE(VFSCompareEntries("/System/Applications/Mail.app", host, tmp_dir.directory / "Mail2.app", host) == 0);
}

TEST_CASE(PREFIX "Modes - RenameToPathPreffix")
{
    // works on single host - In and Out same as where source files are
    // Copies "Mail.app" to "Mail2.app" in the same dir
    const TempTestDir tmp_dir;
    auto dir2 = tmp_dir.directory / "Some" / "Dir" / "Where" / "Files" / "Should" / "Be" / "Renamed/";
    auto host = TestEnv().vfs_native;

    REQUIRE(VFSEasyCopyNode("/System/Applications/Mail.app", host, (tmp_dir.directory / "Mail.app").c_str(), host) ==
            0);

    CopyingOptions opts;
    opts.docopy = false;
    Copying op(FetchItems(tmp_dir, {"Mail.app"}, *host), dir2.native(), host, opts);
    op.Start();
    op.Wait();

    REQUIRE(VFSCompareEntries("/System/Applications/Mail.app", host, dir2 / "Mail.app", host) == 0);
}

TEST_CASE(PREFIX "Modes - RenameToPathName")
{
    // works on single host - In and Out same as where source files are
    // Copies "Mail.app" to "Mail2.app" in the same dir
    const TempTestDir tmp_dir;
    auto host = TestEnv().vfs_native;

    REQUIRE(VFSEasyCopyNode("/System/Applications/Mail.app", host, (tmp_dir.directory / "Mail.app").c_str(), host) ==
            0);

    CopyingOptions opts;
    opts.docopy = false;
    Copying op(FetchItems(tmp_dir, {"Mail.app"}, *host), tmp_dir.directory / "Mail2.app", host, opts);
    op.Start();
    op.Wait();

    REQUIRE(VFSCompareEntries("/System/Applications/Mail.app", host, tmp_dir.directory / "Mail2.app", host) == 0);
}

TEST_CASE(PREFIX "symlinks overwriting")
{
    const TempTestDir tmp_dir;
    symlink("old_symlink_value", (tmp_dir.directory / "file1").c_str());
    symlink("new_symlink_value", (tmp_dir.directory / "file2").c_str());

    CopyingOptions opts;
    opts.docopy = true;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir, {"file2"}, *host), tmp_dir.directory / "file1", host, opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::read_symlink(tmp_dir.directory / "file1") == "new_symlink_value");
}

TEST_CASE(PREFIX "overwriting of symlinks in subdir")
{
    const TempTestDir tmp_dir;
    mkdir((tmp_dir.directory / "D1").c_str(), 0755);
    symlink("old_symlink_value", (tmp_dir.directory / "D1" / "symlink").c_str());
    mkdir((tmp_dir.directory / "D2").c_str(), 0755);
    mkdir((tmp_dir.directory / "D2" / "D1").c_str(), 0755);
    symlink("new_symlink_value", (tmp_dir.directory / "D2" / "D1" / "symlink").c_str());

    CopyingOptions opts;
    opts.docopy = true;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "D2", {"D1"}, *host), tmp_dir.directory, host, opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::read_symlink(tmp_dir.directory / "D1" / "symlink") == "new_symlink_value");
}

TEST_CASE(PREFIX "symlink renaming")
{
    const TempTestDir tmp_dir;
    symlink("symlink_value", (tmp_dir.directory / "file1").c_str());

    CopyingOptions opts;
    opts.docopy = false;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir, {"file1"}, *host), tmp_dir.directory / "file2", host, opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::symlink_status(tmp_dir.directory / "file1").type() ==
            std::filesystem::file_type::not_found);
    REQUIRE(std::filesystem::read_symlink(tmp_dir.directory / "file2") == "symlink_value");
}

static uint32_t FileFlags(const char *path)
{
    struct stat st;
    if( stat(path, &st) != 0 )
        return 0;
    return st.st_flags;
}

TEST_CASE(PREFIX "rename dir into existing dir")
{
    // DirA/TestDir
    // DirB/TestDir
    // DirB/TestDir/file.txt
    const TempTestDir tmp_dir;
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    mkdir((tmp_dir.directory / "DirA" / "TestDir").c_str(), 0755);
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    mkdir((tmp_dir.directory / "DirB" / "TestDir").c_str(), 0755);
    chflags((tmp_dir.directory / "DirB" / "TestDir").c_str(), UF_HIDDEN);
    close(open((tmp_dir.directory / "DirB" / "TestDir" / "file.txt").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));

    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteOld;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"TestDir"}, *host), tmp_dir.directory / "DirA", host, opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirB" / "TestDir").type() ==
            std::filesystem::file_type::not_found);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirA" / "TestDir" / "file.txt").type() ==
            std::filesystem::file_type::regular);
    REQUIRE((FileFlags((tmp_dir.directory / "DirA" / "TestDir").c_str()) & UF_HIDDEN) != 0);
}

TEST_CASE(PREFIX "renaming dir into existing reg")
{
    // DirA/item (file)
    // DirB/item (directory)
    const TempTestDir tmp_dir;
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    close(open((tmp_dir.directory / "DirA" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    mkdir((tmp_dir.directory / "DirB" / "item").c_str(), 0755);

    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"item"}, *host), tmp_dir.directory / "DirA", host, opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirB" / "item").type() ==
            std::filesystem::file_type::not_found);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirA" / "item").type() ==
            std::filesystem::file_type::directory);
}

TEST_CASE(PREFIX "renaming non-empty dir into existing reg")
{
    // DirA/item (file)
    // DirB/item (directory)
    // DirB/item/test
    const TempTestDir tmp_dir;
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    close(open((tmp_dir.directory / "DirA" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    mkdir((tmp_dir.directory / "DirB" / "item").c_str(), 0755);
    close(open((tmp_dir.directory / "DirB" / "item" / "test").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));

    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"item"}, *host), tmp_dir.directory / "DirA", host, opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirB" / "item").type() ==
            std::filesystem::file_type::not_found);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirA" / "item").type() ==
            std::filesystem::file_type::directory);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirA" / "item" / "test").type() ==
            std::filesystem::file_type::regular);
}

TEST_CASE(PREFIX "copied application has a valid signature")
{
    const TempTestDir tmp_dir;
    CopyingOptions opts;
    opts.docopy = true;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems("/System/Applications", {"Mail.app"}, *host), tmp_dir, host, opts);
    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    const auto command = "/usr/bin/codesign --verify --no-strict " + (tmp_dir.directory / "Mail.app").native();
    REQUIRE(system(command.c_str()) == 0);
}

TEST_CASE(PREFIX "copying to existing item with KeepBoth results in orig copied with another name")
{
    const TempTestDir tmp_dir;
    // DirA/item (file)
    // DirB/item (file)
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    close(open((tmp_dir.directory / "DirA" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    close(open((tmp_dir.directory / "DirB" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));

    CopyingOptions opts;
    opts.docopy = true;
    opts.exist_behavior = CopyingOptions::ExistBehavior::KeepBoth;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"item"}, *host), tmp_dir.directory / "DirA", host, opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirA" / "item 2").type() ==
            std::filesystem::file_type::regular);
}

TEST_CASE(PREFIX "renaming to existing item with KeepiBoth results in orig rename with another name")
{
    const TempTestDir tmp_dir;
    // DirA/item (file)
    // DirB/item (file)
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    close(open((tmp_dir.directory / "DirA" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    close(open((tmp_dir.directory / "DirB" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));

    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::KeepBoth;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"item"}, *host), tmp_dir.directory / "DirA", host, opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirA" / "item 2").type() ==
            std::filesystem::file_type::regular);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirB" / "item").type() ==
            std::filesystem::file_type::not_found);
}

TEST_CASE(PREFIX "copying symlink to existing item with KeepBoth results in orig copied with another name")
{
    const TempTestDir tmp_dir;
    // DirA/item (file)
    // DirB/item (simlink)
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    close(open((tmp_dir.directory / "DirA" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    symlink("something", (tmp_dir.directory / "DirB" / "item").c_str());

    CopyingOptions opts;
    opts.docopy = true;
    opts.exist_behavior = CopyingOptions::ExistBehavior::KeepBoth;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"item"}, *host), tmp_dir.directory / "DirA", host, opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::symlink_status(tmp_dir.directory / "DirA" / "item 2").type() ==
            std::filesystem::file_type::symlink);
}

TEST_CASE(PREFIX "renaming symlink to existing item with KeepBoth results in orig renamed with Another name")
{
    const TempTestDir tmp_dir;
    // DirA/item (file)
    // DirB/item (symink)
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    close(open((tmp_dir.directory / "DirA" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    symlink("something", (tmp_dir.directory / "DirB" / "item").c_str());

    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::KeepBoth;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"item"}, *host), tmp_dir.directory / "DirA", host, opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::symlink_status(tmp_dir.directory / "DirA" / "item 2").type() ==
            std::filesystem::file_type::symlink);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirB" / "item").type() ==
            std::filesystem::file_type::not_found);
}

TEST_CASE(PREFIX "Copy native->xattr->xattr")
{
    const TempTestDir tmp_dir;

    const auto native_host = TestEnv().vfs_native;
    const auto orig = tmp_dir.directory / "src";
    const auto noise_size = 123456;
    const auto noise = MakeNoise(noise_size);
    Save(orig, noise);

    const auto xattr1 = tmp_dir.directory / "xattr1";
    fclose(fopen(xattr1.c_str(), "w"));

    const VFSHostPtr src_host = std::make_shared<nc::vfs::XAttrHost>(xattr1.c_str(), native_host);
    {
        Copying op(FetchItems(tmp_dir.directory, {"src"}, *native_host), "/", src_host, {});
        op.Start();
        op.Wait();
        REQUIRE(op.State() == OperationState::Completed);

        REQUIRE(VFSEasyCompareFiles(orig.c_str(), native_host, "/src", src_host) == 0);
    }

    const auto xattr2 = tmp_dir.directory / "xattr2";
    fclose(fopen(xattr2.c_str(), "w"));
    const VFSHostPtr dst_host = std::make_shared<nc::vfs::XAttrHost>(xattr2.c_str(), native_host);
    {
        Copying op(FetchItems("/", {"src"}, *src_host), "/dst", dst_host, {});
        op.Start();
        op.Wait();

        REQUIRE(VFSEasyCompareFiles(orig.c_str(), native_host, "/dst", dst_host) == 0);
    }
}

TEST_CASE(PREFIX "Copy to local FTP, part1")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<nc::vfs::FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));

    const char *fn1 = "/System/Library/Kernels/kernel";
    const char *fn2 = "/Public/!FilesTesting/kernel";

    std::ignore = VFSEasyDelete(fn2, host);

    const CopyingOptions opts;
    Copying op(FetchItems("/System/Library/Kernels/", {"kernel"}, *TestEnv().vfs_native),
               "/Public/!FilesTesting/",
               host,
               opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);

    REQUIRE(VFSEasyCompareFiles(fn1, TestEnv().vfs_native, fn2, host) == 0);

    REQUIRE(host->Unlink(fn2));
}

TEST_CASE(PREFIX "Copy to local FTP")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<nc::vfs::FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));

    auto files = std::vector<std::string>{"Info.plist", "PkgInfo", "version.plist"};

    std::ignore = VFSEasyDelete("/Public", host);

    const CopyingOptions opts;
    Copying op(FetchItems("/System/Applications/Mail.app/Contents", {begin(files), end(files)}, *TestEnv().vfs_native),
               "/Public/!FilesTesting/",
               host,
               opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);

    for( auto &i : files ) {
        REQUIRE(VFSEasyCompareFiles(("/System/Applications/Mail.app/Contents/" + i).c_str(),
                                    TestEnv().vfs_native,
                                    ("/Public/!FilesTesting/" + i).c_str(),
                                    host) == 0);
        REQUIRE(host->Unlink("/Public/!FilesTesting/" + i));
    }

    std::ignore = VFSEasyDelete("/Public", host);
}

TEST_CASE(PREFIX "Copy to local FTP, part3")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<nc::vfs::FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));

    std::ignore = VFSEasyDelete("/Public/!FilesTesting/bin", host);

    const CopyingOptions opts;
    Copying op(FetchItems("/", {"bin"}, *TestEnv().vfs_native), "/Public/!FilesTesting/", host, opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);

    REQUIRE(VFSCompareEntries("/bin", TestEnv().vfs_native, "/Public/!FilesTesting/bin", host) == 0);

    std::ignore = VFSEasyDelete("/Public/!FilesTesting/bin", host);
}

TEST_CASE(PREFIX "Copy to local FTP part4")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<nc::vfs::FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));

    const char *fn1 = "/System/Library/Kernels/kernel";
    const char *fn2 = "/Public/!FilesTesting/kernel";
    const char *fn3 = "/Public/!FilesTesting/kernel copy";

    std::ignore = VFSEasyDelete(fn2, host);
    std::ignore = VFSEasyDelete(fn3, host);

    {
        Copying op(FetchItems("/System/Library/Kernels/", {"kernel"}, *TestEnv().vfs_native),
                   "/Public/!FilesTesting/",
                   host,
                   {});
        op.Start();
        op.Wait();
        REQUIRE(op.State() == OperationState::Completed);
    }

    REQUIRE(VFSEasyCompareFiles(fn1, TestEnv().vfs_native, fn2, host) == 0);

    {
        Copying op(FetchItems("/Public/!FilesTesting/", {"kernel"}, *host), fn3, host, {});
        op.Start();
        op.Wait();
        REQUIRE(op.State() == OperationState::Completed);
    }

    REQUIRE(VFSEasyCompareFiles(fn2, host, fn3, host) == 0);

    REQUIRE(host->Unlink(fn2));
    REQUIRE(host->Unlink(fn3));
}

TEST_CASE(PREFIX "Copy to local FTP, special characters")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<nc::vfs::FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
    const std::filesystem::path dir = "/Testing";

    std::ignore = VFSEasyDelete(dir.c_str(), host);

    struct TestCase {
        std::filesystem::path name;
    } const tcs[] = {
        {"sleep"},                   // original
        {"sleep "},                  // trailing space
        {" sleep"},                  // heading space
        {"yet another dir / sleep"}, // spaces with a directory
        {"!@#$%^&*()_=-+.`'"},       // non-alphanum
        {"мяу"},                     // non-ascii
        {"🤡🤡"},                    // emoji
        {"🤡/😀/😄/😁/😆/🥹/😅/😂"}, // emoji directories
    };

    for( auto &tc : tcs ) {
        {
            Copying op(FetchItems("/bin", {"sleep"}, *TestEnv().vfs_native), dir / tc.name, host, {});
            op.Start();
            op.Wait();
            REQUIRE(op.State() == OperationState::Completed);
        }
        REQUIRE(VFSEasyCompareFiles("/bin/sleep", TestEnv().vfs_native, (dir / tc.name).c_str(), host) == 0);
        REQUIRE(host->Unlink((dir / tc.name).c_str()));
    }

    std::ignore = VFSEasyDelete(dir.c_str(), host);
}

TEST_CASE(PREFIX "Renaming a locked native regular item")
{
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    const auto filename = "old_name";
    const auto filename_new = "new_name";
    const auto path = dir.directory / filename;
    auto exists = [](const std::string &_path) -> bool {
        struct stat st;
        return lstat(_path.c_str(), &st) == 0;
    };
    auto setup = [&] {
        SECTION("Regular file")
        {
            REQUIRE(close(creat(path.c_str(), 0755)) == 0);
            REQUIRE(lchflags(path.c_str(), UF_IMMUTABLE) == 0);
        }
        SECTION("Symlink")
        {
            REQUIRE_NOTHROW(std::filesystem::create_symlink("some nonsense", path));
            REQUIRE(lchflags(path.c_str(), UF_IMMUTABLE) == 0);
        }
        SECTION("Directory")
        {
            REQUIRE_NOTHROW(std::filesystem::create_directory(path));
            REQUIRE(lchflags(path.c_str(), UF_IMMUTABLE) == 0);
        }
    };

    CopyingOptions opts;
    opts.docopy = false;

    std::unique_ptr<Copying> op;
    auto run = [&] {
        op = std::make_unique<Copying>(
            FetchItems(dir.directory, {filename}, *host), dir.directory / filename_new, host, opts);
        op->Start();
        op->Wait();
    };
    SECTION("Default - ask")
    {
        setup();
        run();
        REQUIRE(op->State() == OperationState::Stopped);
        REQUIRE(exists(path));
        REQUIRE(lchflags(path.c_str(), 0) == 0);
    }
    SECTION("Default - skip")
    {
        setup();
        opts.locked_items_behaviour = CopyingOptions::LockedItemBehavior::SkipAll;
        run();
        REQUIRE(op->State() == OperationState::Completed);
        REQUIRE(exists(path));
        REQUIRE(lchflags(path.c_str(), 0) == 0);
    }
    SECTION("Default - stop")
    {
        setup();
        opts.locked_items_behaviour = CopyingOptions::LockedItemBehavior::Stop;
        run();
        REQUIRE(op->State() == OperationState::Stopped);
        REQUIRE(exists(path));
        REQUIRE(lchflags(path.c_str(), 0) == 0);
    }
    SECTION("Default - unlock")
    {
        setup();
        opts.locked_items_behaviour = CopyingOptions::LockedItemBehavior::UnlockAll;
        run();
        REQUIRE(op->State() == OperationState::Completed);
        REQUIRE(exists(path) == false);
        REQUIRE(exists(dir.directory / filename_new) == true);
    }
}

TEST_CASE(PREFIX "Overwriting a locked native regular item")
{
    using LockedItemBehavior = CopyingOptions::LockedItemBehavior;

    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    const auto filename_src = "source";
    const auto filename_dst = "destination";
    const auto path_src = dir.directory / filename_src;
    const auto path_dst = dir.directory / filename_dst;
    const auto old_sz = ssize_t(76);
    const auto new_sz = ssize_t(33);

    auto exists = [](const std::filesystem::path &_path) -> bool {
        struct stat st;
        return lstat(_path.c_str(), &st) == 0;
    };
    auto file_size = [](const std::filesystem::path &_path) -> ssize_t {
        struct stat st;
        return (lstat(_path.c_str(), &st) == 0) ? st.st_size : -1;
    };

    struct TestCase {
        bool do_copy;
        CopyingOptions::LockedItemBehavior locked_behaviour;
        OperationState state;
        bool src_exist;
        bool dst_exist;
        ssize_t dst_size;
    } const test_cases[] = {
        {.do_copy = true,
         .locked_behaviour = LockedItemBehavior::Ask,
         .state = OperationState::Stopped,
         .src_exist = true,
         .dst_exist = true,
         .dst_size = old_sz},
        {.do_copy = true,
         .locked_behaviour = LockedItemBehavior::SkipAll,
         .state = OperationState::Completed,
         .src_exist = true,
         .dst_exist = true,
         .dst_size = old_sz},
        {.do_copy = true,
         .locked_behaviour = LockedItemBehavior::UnlockAll,
         .state = OperationState::Completed,
         .src_exist = true,
         .dst_exist = true,
         .dst_size = new_sz},
        {.do_copy = true,
         .locked_behaviour = LockedItemBehavior::Stop,
         .state = OperationState::Stopped,
         .src_exist = true,
         .dst_exist = true,
         .dst_size = old_sz},
        {.do_copy = false,
         .locked_behaviour = LockedItemBehavior::Ask,
         .state = OperationState::Stopped,
         .src_exist = true,
         .dst_exist = true,
         .dst_size = old_sz},
        {.do_copy = false,
         .locked_behaviour = LockedItemBehavior::SkipAll,
         .state = OperationState::Completed,
         .src_exist = true,
         .dst_exist = true,
         .dst_size = old_sz},
        {.do_copy = false,
         .locked_behaviour = LockedItemBehavior::UnlockAll,
         .state = OperationState::Completed,
         .src_exist = false,
         .dst_exist = true,
         .dst_size = new_sz},
        {.do_copy = false,
         .locked_behaviour = LockedItemBehavior::Stop,
         .state = OperationState::Stopped,
         .src_exist = true,
         .dst_exist = true,
         .dst_size = old_sz},
    };

    for( const auto test_case : test_cases ) {
        // create files to tinker with
        REQUIRE(close(creat(path_src.c_str(), 0755)) == 0);
        REQUIRE_NOTHROW(std::filesystem::resize_file(path_src, new_sz));
        REQUIRE(close(creat(path_dst.c_str(), 0755)) == 0);
        REQUIRE_NOTHROW(std::filesystem::resize_file(path_dst, old_sz));
        REQUIRE(lchflags(path_dst.c_str(), UF_IMMUTABLE) == 0);

        // perform an operation
        CopyingOptions opts;
        opts.docopy = test_case.do_copy;
        opts.locked_items_behaviour = test_case.locked_behaviour;
        opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
        Copying op(FetchItems(dir.directory, {filename_src}, *host), path_dst, host, opts);
        op.Start();
        op.Wait();

        // check what happened
        REQUIRE(op.State() == test_case.state);
        REQUIRE(exists(path_src) == test_case.src_exist);
        REQUIRE(exists(path_dst) == test_case.dst_exist);
        REQUIRE(file_size(path_dst) == test_case.dst_size);

        // cleanup
        if( exists(path_src) ) {
            REQUIRE(remove(path_src.c_str()) == 0);
        }
        if( exists(path_dst) ) {
            REQUIRE(lchflags(path_dst.c_str(), 0) == 0);
            REQUIRE(remove(path_dst.c_str()) == 0);
        }
    }
}

TEST_CASE(PREFIX "Moving a locked native regular item to a separate volume")
{
    // creating/mounting a .dmg is rather slow, so this is a sequential test instead of multiple
    // sections.
    TempTestDir dir;
    const TempTestDmg dmg(dir);
    const auto host = TestEnv().vfs_native;
    const auto filename = "old_name";
    const auto new_filename = "old_name";
    const auto path = dir.directory / filename;
    const auto new_path = dmg.directory / new_filename;

    auto exists = [](const std::string &_path) -> bool {
        struct stat st;
        return ::lstat(_path.c_str(), &st) == 0;
    };
    auto remove = [](const std::string &_path) -> bool {
        return ::lchflags(_path.c_str(), 0) == 0 && ::remove(_path.c_str()) == 0;
    };
    auto run = [&](CopyingOptions &opts) -> std::unique_ptr<Copying> {
        auto op = std::make_unique<Copying>(FetchItems(dir.directory, {filename}, *host), new_path, host, opts);
        op->Start();
        op->Wait();
        return op;
    };
    const std::vector<std::function<void()>> setups{[&] {
                                                        REQUIRE(close(creat(path.c_str(), 0755)) == 0);
                                                        REQUIRE(lchflags(path.c_str(), UF_IMMUTABLE) == 0);
                                                    },
                                                    [&] {
                                                        REQUIRE_NOTHROW(
                                                            std::filesystem::create_symlink("some nonsense", path));
                                                        REQUIRE(lchflags(path.c_str(), UF_IMMUTABLE) == 0);
                                                    },
                                                    [&] {
                                                        REQUIRE_NOTHROW(std::filesystem::create_directory(path));
                                                        REQUIRE(lchflags(path.c_str(), UF_IMMUTABLE) == 0);
                                                    }};
    for( auto &setup : setups ) {
        CopyingOptions opts;
        opts.docopy = false;

        {
            opts.locked_items_behaviour = CopyingOptions::LockedItemBehavior::Ask;
            setup();
            auto op = run(opts);
            REQUIRE(op->State() == OperationState::Stopped);
            REQUIRE(exists(path));
            REQUIRE(exists(new_path));
            REQUIRE(remove(path));
            REQUIRE(remove(new_path));
        }
        {
            opts.locked_items_behaviour = CopyingOptions::LockedItemBehavior::SkipAll;
            setup();
            auto op = run(opts);
            REQUIRE(op->State() == OperationState::Completed);
            REQUIRE(exists(path));
            REQUIRE(exists(new_path));
            REQUIRE(remove(path));
            REQUIRE(remove(new_path));
        }
        {
            opts.locked_items_behaviour = CopyingOptions::LockedItemBehavior::Stop;
            setup();
            auto op = run(opts);
            REQUIRE(op->State() == OperationState::Stopped);
            REQUIRE(exists(path));
            REQUIRE(exists(new_path));
            REQUIRE(remove(path));
            REQUIRE(remove(new_path));
        }
        {
            opts.locked_items_behaviour = CopyingOptions::LockedItemBehavior::UnlockAll;
            setup();
            auto op = run(opts);
            REQUIRE(op->State() == OperationState::Completed);
            REQUIRE(exists(path) == false);
            REQUIRE(exists(new_path));
            REQUIRE(remove(new_path));
        }
    }
}

// TODO: perm fixup also need a test to check the reversed order of the chmod() executions

TEST_CASE(PREFIX "Setting directory permissions in an epilogue - (native -> native)")
{
    TempTestDir dir;
    REQUIRE(mkdir((dir.directory / "dir").c_str(), S_IRWXU) == 0);
    REQUIRE(close(open((dir.directory / "dir/file").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR)) == 0);
    REQUIRE(chmod((dir.directory / "dir").c_str(), S_IRUSR | S_IXUSR) == 0);
    auto revert_mod = at_scope_end([&] { chmod((dir.directory / "dir").c_str(), S_IRWXU); });
    auto host = TestEnv().vfs_native;
    auto eq = [](const struct timespec &_lhs, const struct timespec &_rhs) {
        return _lhs.tv_sec == _rhs.tv_sec && _lhs.tv_nsec == _rhs.tv_nsec;
    };
    auto less = [](const struct timespec &_lhs, const struct timespec &_rhs) {
        return _lhs.tv_sec < _rhs.tv_sec || (_lhs.tv_sec == _rhs.tv_sec && _lhs.tv_nsec < _rhs.tv_nsec);
    };

    CopyingOptions opts;
    opts.docopy = true;
    struct stat st1;
    struct stat st2;
    SECTION("Copy flags and times")
    {
        opts.copy_unix_flags = true;
        opts.copy_file_times = true;
        Copying op(FetchItems(dir.directory, {"dir"}, *host), dir.directory / "dir2", host, opts);
        op.Start();
        op.Wait();
        REQUIRE(op.State() == OperationState::Completed);
        REQUIRE(::stat((dir.directory / "dir").c_str(), &st1) == 0);
        REQUIRE(::stat((dir.directory / "dir2").c_str(), &st2) == 0);
        CHECK(st1.st_mode == st2.st_mode);
        CHECK(eq(st1.st_mtimespec, st2.st_mtimespec));
        CHECK(eq(st1.st_birthtimespec, st2.st_birthtimespec));
        chmod((dir.directory / "dir2").c_str(), S_IRWXU);
    }
    SECTION("Only times")
    {
        opts.copy_unix_flags = false;
        opts.copy_file_times = true;
        Copying op(FetchItems(dir.directory, {"dir"}, *host), dir.directory / "dir2", host, opts);
        op.Start();
        op.Wait();
        REQUIRE(op.State() == OperationState::Completed);
        REQUIRE(::stat((dir.directory / "dir").c_str(), &st1) == 0);
        REQUIRE(::stat((dir.directory / "dir2").c_str(), &st2) == 0);
        CHECK(st1.st_mode != st2.st_mode);
        CHECK(eq(st1.st_mtimespec, st2.st_mtimespec));
        CHECK(eq(st1.st_birthtimespec, st2.st_birthtimespec));
    }
    SECTION("Only flags ")
    {
        opts.copy_unix_flags = true;
        opts.copy_file_times = false;
        Copying op(FetchItems(dir.directory, {"dir"}, *host), dir.directory / "dir2", host, opts);
        op.Start();
        op.Wait();
        REQUIRE(op.State() == OperationState::Completed);
        REQUIRE(::stat((dir.directory / "dir").c_str(), &st1) == 0);
        REQUIRE(::stat((dir.directory / "dir2").c_str(), &st2) == 0);
        CHECK(st1.st_mode == st2.st_mode);
        CHECK(less(st1.st_mtimespec, st2.st_mtimespec));
        CHECK(less(st1.st_birthtimespec, st2.st_birthtimespec));
        chmod((dir.directory / "dir2").c_str(), S_IRWXU);
    }
    SECTION("Neither flags nor times")
    {
        opts.copy_unix_flags = false;
        opts.copy_file_times = false;
        Copying op(FetchItems(dir.directory, {"dir"}, *host), dir.directory / "dir2", host, opts);
        op.Start();
        op.Wait();
        REQUIRE(op.State() == OperationState::Completed);
        REQUIRE(::stat((dir.directory / "dir").c_str(), &st1) == 0);
        REQUIRE(::stat((dir.directory / "dir2").c_str(), &st2) == 0);
        CHECK(st1.st_mode != st2.st_mode);
        CHECK(less(st1.st_mtimespec, st2.st_mtimespec));
        CHECK(less(st1.st_birthtimespec, st2.st_birthtimespec));
    }
}

TEST_CASE(PREFIX "Setting directory permissions in an epilogue - (vfs -> native)")
{
    //            |-- no write perm on the directory
    //            V
    // d:       dr-xr-xr-x
    // d/f.txt: -rw-r--r--
    const unsigned char arc[] = {
        0x1f, 0x8b, 0x08, 0x00, 0x08, 0xc1, 0xfe, 0x65, 0x00, 0x03, 0x4b, 0xd1, 0x67, 0xa0, 0x39, 0x30, 0x30, 0x30,
        0x30, 0x35, 0x35, 0x55, 0x00, 0xd1, 0xe6, 0x66, 0x10, 0xda, 0xc0, 0xc8, 0x04, 0x42, 0x43, 0x81, 0x82, 0xa1,
        0x89, 0xa9, 0xb9, 0xb9, 0xa9, 0x89, 0x81, 0x91, 0x99, 0x89, 0x82, 0x81, 0xa1, 0x21, 0x90, 0xc3, 0xa0, 0x60,
        0x4a, 0x7b, 0xa7, 0x31, 0x30, 0x94, 0x16, 0x97, 0x24, 0x16, 0x01, 0x9d, 0x92, 0x9b, 0x99, 0x5e, 0x9a, 0x87,
        0x47, 0x1d, 0x50, 0x59, 0x5a, 0x1a, 0x1e, 0x79, 0xa8, 0x3f, 0xe0, 0xf4, 0x10, 0x01, 0x29, 0xfa, 0x7a, 0xf1,
        0x69, 0x7a, 0x25, 0x15, 0x25, 0x34, 0xb4, 0x03, 0x18, 0x1e, 0x66, 0x26, 0x26, 0xb8, 0xe3, 0xdf, 0xcc, 0x0c,
        0x3d, 0xfe, 0x8d, 0x81, 0x82, 0x0c, 0x0a, 0x06, 0x34, 0x74, 0x13, 0x1c, 0x8c, 0xf0, 0xf8, 0x67, 0x60, 0x15,
        0x63, 0x67, 0x60, 0x62, 0x60, 0xf0, 0x4d, 0x4c, 0x56, 0xf0, 0x0f, 0x56, 0x88, 0x50, 0x80, 0x02, 0x90, 0x18,
        0x03, 0x27, 0x10, 0x1b, 0x31, 0x30, 0x30, 0xd6, 0x01, 0x69, 0x20, 0x9f, 0x71, 0x03, 0x71, 0x46, 0x3a, 0x86,
        0x84, 0x04, 0x41, 0x58, 0x20, 0x1d, 0x8c, 0x1c, 0x40, 0xc6, 0x0a, 0x34, 0x25, 0xcc, 0x50, 0x71, 0x7e, 0x06,
        0x06, 0xf1, 0xe4, 0xfc, 0x5c, 0xbd, 0xc4, 0x82, 0x82, 0x9c, 0x54, 0xbd, 0x90, 0xd4, 0x8a, 0x12, 0xd7, 0xbc,
        0xe4, 0xfc, 0x94, 0xcc, 0xbc, 0x74, 0x88, 0x7e, 0x71, 0x20, 0x21, 0xc0, 0xc0, 0x20, 0x85, 0x50, 0x93, 0x93,
        0x58, 0x5c, 0x52, 0x5a, 0x9c, 0x9a, 0x92, 0x92, 0x58, 0x92, 0xaa, 0x1c, 0x10, 0x0c, 0xb5, 0x47, 0x1d, 0x48,
        0x74, 0x32, 0x30, 0x98, 0x23, 0xd4, 0xe5, 0xa6, 0x96, 0x24, 0x02, 0xd5, 0x24, 0x5a, 0x65, 0xfb, 0xba, 0xf8,
        0x24, 0x26, 0xa5, 0xe6, 0xc4, 0x9b, 0x24, 0x96, 0x9a, 0x17, 0x67, 0x17, 0x27, 0x15, 0x57, 0xe4, 0x65, 0x65,
        0x17, 0xa7, 0x55, 0xa4, 0x99, 0x97, 0xe7, 0xa4, 0xe4, 0x25, 0x15, 0x9a, 0x98, 0x00, 0x35, 0x97, 0x96, 0xa4,
        0xe9, 0x5a, 0x58, 0x1b, 0x1a, 0x9b, 0x18, 0x19, 0x9a, 0x5b, 0x5a, 0x98, 0x6c, 0x3c, 0xf0, 0x2f, 0x15, 0x64,
        0x70, 0xd4, 0xb3, 0x1f, 0x5c, 0x20, 0xfa, 0x13, 0x3b, 0xe3, 0x21, 0xa1, 0xcd, 0x8a, 0x27, 0xa7, 0x0a, 0x3e,
        0x67, 0x7c, 0xb7, 0xb5, 0x3c, 0x6e, 0xd5, 0x21, 0x9f, 0xb9, 0x0f, 0x34, 0x79, 0xe2, 0xce, 0x6e, 0xb2, 0xf0,
        0x9c, 0x78, 0x57, 0xa6, 0x5d, 0xee, 0xd5, 0xd1, 0xbc, 0x8f, 0xba, 0xc5, 0xce, 0x73, 0x96, 0x45, 0x4a, 0xf4,
        0x6e, 0x98, 0x67, 0x57, 0x75, 0x69, 0x93, 0xe3, 0xe1, 0x3f, 0x19, 0x6a, 0x5e, 0xc7, 0x6f, 0x1e, 0x73, 0xb4,
        0x29, 0x9a, 0x7e, 0x4f, 0x22, 0x66, 0xc7, 0x09, 0x89, 0xa4, 0xd0, 0x0f, 0x21, 0x8a, 0x73, 0xbf, 0x3d, 0x9a,
        0x58, 0x54, 0xb5, 0x96, 0x73, 0x42, 0x7d, 0x89, 0xf8, 0x9e, 0x45, 0xd9, 0x3c, 0xf7, 0x1e, 0x08, 0xa8, 0x4e,
        0x4b, 0xe0, 0xde, 0xf6, 0xb4, 0xff, 0x90, 0xd2, 0xad, 0xb0, 0x5d, 0x46, 0x8f, 0xdf, 0x67, 0x72, 0x73, 0x5f,
        0x5a, 0xf8, 0x38, 0x64, 0xce, 0x7a, 0xb7, 0x9e, 0x0a, 0xd7, 0x57, 0x66, 0x6b, 0xde, 0xa5, 0x7c, 0x35, 0xdd,
        0xe0, 0xa0, 0xbc, 0x4f, 0x4d, 0xe4, 0xc4, 0x1b, 0xf2, 0x23, 0x1a, 0x3b, 0x48, 0xd1, 0x0f, 0x48, 0xac, 0xf0,
        0x48, 0x4d, 0x4c, 0x49, 0x2d, 0xd2, 0xa7, 0x55, 0x39, 0x40, 0x20, 0xff, 0x1b, 0x1a, 0x9b, 0xa2, 0xe7, 0x7f,
        0x13, 0x53, 0x63, 0x60, 0xf9, 0x5f, 0x41, 0x03, 0xb7, 0x60, 0x80, 0x11, 0x9e, 0xff, 0x8d, 0xcc, 0x15, 0x72,
        0x4b, 0x32, 0x73, 0x53, 0x6d, 0x0d, 0xcd, 0x0d, 0x0d, 0x0d, 0x2d, 0x4d, 0x8c, 0x2c, 0x8d, 0xf4, 0x80, 0xa1,
        0x6f, 0x69, 0x68, 0xc1, 0x65, 0x04, 0x2c, 0x96, 0x7d, 0x3c, 0x9d, 0x1c, 0x83, 0x9c, 0x3d, 0x3c, 0xc3, 0x5c,
        0xf5, 0x2a, 0x12, 0x4b, 0x4a, 0x8a, 0xf4, 0xc8, 0xcb, 0x60, 0xb6, 0x16, 0xe9, 0xc9, 0x4e, 0xe5, 0x19, 0xde,
        0x55, 0x9e, 0xc9, 0xb9, 0x61, 0xae, 0xa9, 0xc9, 0x4e, 0xe6, 0x45, 0x61, 0xc6, 0x11, 0x85, 0x45, 0xce, 0x21,
        0x5e, 0xc6, 0xe9, 0xde, 0x81, 0x15, 0xa9, 0x55, 0x49, 0x9e, 0x26, 0xc1, 0x51, 0x1e, 0x29, 0x1e, 0x9e, 0xc9,
        0xa9, 0x66, 0xc5, 0x61, 0xa5, 0x16, 0xc1, 0x86, 0x55, 0x81, 0xa6, 0x95, 0xb9, 0xe1, 0x41, 0x99, 0x7e, 0xc5,
        0x5e, 0x26, 0xda, 0xa9, 0x25, 0xde, 0x95, 0x81, 0xc9, 0x01, 0x16, 0x89, 0xce, 0x51, 0xde, 0x15, 0x96, 0x79,
        0xee, 0x81, 0x21, 0x15, 0x95, 0x39, 0x96, 0x26, 0x91, 0x11, 0x3e, 0x59, 0x9e, 0xee, 0xee, 0x5e, 0x61, 0x16,
        0x6e, 0x81, 0x19, 0x79, 0x69, 0x49, 0x99, 0xd9, 0x11, 0x5e, 0x66, 0x45, 0x81, 0xb9, 0x81, 0x69, 0xc6, 0x81,
        0x11, 0x65, 0xde, 0x5e, 0x45, 0x2e, 0x7e, 0xe6, 0xe9, 0xae, 0xce, 0xe1, 0xe1, 0x91, 0x8e, 0xa5, 0x46, 0xa6,
        0x91, 0xfa, 0xce, 0x9e, 0x25, 0x05, 0xe1, 0xa5, 0x59, 0x3e, 0x59, 0xe6, 0x46, 0xd9, 0x3e, 0xce, 0x96, 0xde,
        0x19, 0x26, 0x86, 0xc1, 0xc9, 0x45, 0x06, 0x89, 0xbe, 0xa9, 0xae, 0x11, 0x85, 0x7e, 0x85, 0x55, 0xa5, 0x51,
        0x01, 0xa1, 0x86, 0xc5, 0xae, 0x8e, 0x59, 0x65, 0x99, 0x91, 0xa1, 0x95, 0xfe, 0xe5, 0x5c, 0x46, 0x86, 0x06,
        0x0a, 0xc1, 0x40, 0xff, 0xfb, 0x44, 0x52, 0xe6, 0xff, 0x41, 0x53, 0x7e, 0x70, 0x99, 0x59, 0xe2, 0x8b, 0x54,
        0xb4, 0xd2, 0xd5, 0xb6, 0x38, 0xd9, 0x45, 0x3b, 0x2a, 0xd0, 0x11, 0x08, 0x9c, 0x12, 0x4d, 0xcb, 0xd2, 0xbd,
        0x1d, 0xc1, 0x80, 0xcb, 0xd4, 0x12, 0x57, 0xa8, 0xa0, 0x1b, 0x80, 0x5e, 0x90, 0x72, 0x01, 0xf3, 0x37, 0x1e,
        0xfb, 0x91, 0x6b, 0x00, 0xdb, 0x94, 0x88, 0xa0, 0x5c, 0x9f, 0x90, 0x74, 0x73, 0xdf, 0x10, 0x5f, 0x03, 0xdf,
        0x2c, 0x57, 0x63, 0xff, 0x90, 0x74, 0x03, 0x2e, 0x60, 0x43, 0x12, 0x87, 0xd5, 0x28, 0x7a, 0xd1, 0xca, 0x73,
        0xae, 0x81, 0xcd, 0x65, 0x83, 0x17, 0xa4, 0xd0, 0xac, 0xd4, 0x47, 0x00, 0x42, 0xed, 0x3f, 0xa0, 0x34, 0x5a,
        0xf9, 0x6f, 0x64, 0x6a, 0x66, 0x3c, 0xda, 0xfe, 0xa3, 0x07, 0xf0, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0x1c, 0x68,
        0x57, 0x8c, 0x82, 0x51, 0x30, 0x0a, 0x46, 0xc1, 0x28, 0xa0, 0x37, 0x00, 0x00, 0xd9, 0x11, 0xfa, 0x57, 0x00,
        0x14, 0x00, 0x00};

    const TempTestDir dir;
    const auto path = std::filesystem::path(dir.directory) / "arc";
    REQUIRE(nc::base::WriteAtomically(path, {reinterpret_cast<const std::byte *>(arc), std::size(arc)}));
    std::shared_ptr<nc::vfs::ArchiveHost> host;
    REQUIRE_NOTHROW(host = std::make_shared<nc::vfs::ArchiveHost>(path.c_str(), TestEnv().vfs_native));

    CopyingOptions opts;
    opts.docopy = true;
    struct stat st;
    SECTION("Copy unix flags")
    {
        opts.copy_unix_flags = true;
        Copying op(FetchItems("/", {"d"}, *host), dir.directory / "d", TestEnv().vfs_native, opts);
        op.Start();
        op.Wait();
        REQUIRE(op.State() == OperationState::Completed);
        REQUIRE(::stat((dir.directory / "d").c_str(), &st) == 0);
        CHECK((st.st_mode & (S_IRWXU | S_IRWXG | S_IRWXO)) ==
              (S_IRUSR | S_IXUSR | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
        REQUIRE(VFSEasyCompareFiles((dir.directory / "d/f.txt").c_str(), TestEnv().vfs_native, "/d/f.txt", host) == 0);
        chmod((dir.directory / "d").c_str(), S_IRWXU);
    }
    SECTION("Don't copy unix flags")
    {
        opts.copy_unix_flags = false;
        Copying op(FetchItems("/", {"d"}, *host), dir.directory / "d", TestEnv().vfs_native, opts);
        op.Start();
        op.Wait();
        REQUIRE(op.State() == OperationState::Completed);
        REQUIRE(::stat((dir.directory / "d").c_str(), &st) == 0);
        CHECK((st.st_mode & (S_IRWXU | S_IRWXG | S_IRWXO)) ==
              (S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
        REQUIRE(VFSEasyCompareFiles((dir.directory / "d/f.txt").c_str(), TestEnv().vfs_native, "/d/f.txt", host) == 0);
    }
}

TEST_CASE(PREFIX "Setting directory permissions in an epilogue - (vfs -> vfs)")
{
    TempTestDir dir;
    REQUIRE(mkdir((dir.directory / "dir").c_str(), S_IRWXU) == 0);
    REQUIRE(close(open((dir.directory / "dir/file").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR)) == 0);
    REQUIRE(chmod((dir.directory / "dir").c_str(), S_IRUSR | S_IXUSR) == 0);
    auto revert_mod = at_scope_end([&] { chmod((dir.directory / "dir").c_str(), S_IRWXU); });

    auto host = TestEnvironment::SpawnSFTPHost();
    REQUIRE(host);
    const std::filesystem::path target_dir = std::filesystem::path(host->HomeDir()) / "__nc_operations_test";
    std::ignore = VFSEasyDelete(target_dir.c_str(), host);

    CopyingOptions opts;
    opts.docopy = true;
    SECTION("Copy unix flags")
    {
        opts.copy_unix_flags = true;
        Copying op(FetchItems(dir.directory, {"dir"}, *TestEnv().vfs_native), target_dir, host, opts);
        op.Start();
        op.Wait();
        REQUIRE(op.State() == OperationState::Completed);
        REQUIRE(host->Stat(target_dir.c_str(), 0).value().mode == (S_IFDIR | S_IRUSR | S_IXUSR));
        REQUIRE(host->SetPermissions(target_dir.c_str(), S_IRWXU));
    }
    SECTION("Don't copy unix flags")
    {
        opts.copy_unix_flags = false;
        Copying op(FetchItems(dir.directory, {"dir"}, *TestEnv().vfs_native), target_dir, host, opts);
        op.Start();
        op.Wait();
        REQUIRE(op.State() == OperationState::Completed);
        REQUIRE(host->Stat(target_dir.c_str(), 0).value().mode ==
                (S_IFDIR | S_IRUSR | S_IXUSR | S_IWUSR | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH));
    }

    std::ignore = VFSEasyDelete(target_dir.c_str(), host);
}

TEST_CASE(PREFIX "Copying a native file that is being written to")
{
    const TempTestDir dir;
    const std::filesystem::path p = dir.directory / "a";
    static constexpr size_t max_size = 100'000'000;

    std::mutex m;
    std::condition_variable cv; // should be a std::latch instead, but isn't
                                // available on macosx10.15 :-(
    std::atomic_bool started = false;
    std::atomic_bool stop = false;
    std::thread t([&] {
        const int f = open(p.c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR);
        REQUIRE(f >= 0);
        for( size_t i = 0; !stop && i < max_size; ++i ) {
            write(f, &f, 1);

            if( i == 0 ) {
                started = true;
                cv.notify_all();
            }
        }
        close(f);
    });

    // wait until the writing has started on the background thread
    std::unique_lock lk(m);
    REQUIRE(cv.wait_for(lk, std::chrono::seconds{5}, [&] { return started.load(); }));

    CopyingOptions opts;
    opts.docopy = true;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(dir.directory, {"a"}, *host), dir.directory / "b", host, opts);
    op.Start();
    op.Wait();

    stop = true;
    t.join();

    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::status(dir.directory / "b").type() == std::filesystem::file_type::regular);
    const size_t sz_a = std::filesystem::file_size(p);
    const size_t sz_b = std::filesystem::file_size(dir.directory / "b");
    CHECK(sz_a < max_size);
    CHECK(sz_b < sz_a);
}

static std::vector<std::byte> MakeNoise(size_t _size)
{
    std::vector<std::byte> bytes(_size);
    for( auto &b : bytes )
        b = static_cast<std::byte>(std::rand() % 256);
    return bytes;
}

static bool Save(const std::filesystem::path &_filepath, std::span<const std::byte> _content)
{
    std::ofstream out(_filepath, std::ios::out | std::ios::binary);
    if( !out )
        return false;
    out.write(reinterpret_cast<const char *>(_content.data()), _content.size());
    out.close();
    return true;
}

static std::expected<int, Error> VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                                                   const VFSHostPtr &_file1_host,
                                                   const std::filesystem::path &_file2_full_path,
                                                   const VFSHostPtr &_file2_host)
{
    // TODO: rewrite this!
    // not comparing contents, flags, perm, times, xattrs, acls etc now

    const std::expected<VFSStat, Error> st1 = _file1_host->Stat(_file1_full_path.c_str(), 0);
    if( !st1 )
        return std::unexpected(st1.error());

    const std::expected<VFSStat, Error> st2 = _file2_host->Stat(_file2_full_path.c_str(), 0);
    if( !st2 )
        return std::unexpected(st2.error());

    if( (st1->mode & S_IFMT) != (st2->mode & S_IFMT) ) {
        return -1;
    }

    if( S_ISREG(st1->mode) ) {
        return int(int64_t(st1->size) - int64_t(st2->size));
    }
    else if( S_ISDIR(st1->mode) ) {
        std::expected<int, Error> result = 0;
        std::ignore = _file1_host->IterateDirectoryListing(_file1_full_path.c_str(), [&](const VFSDirEnt &_dirent) {
            result = VFSCompareEntries(
                _file1_full_path / _dirent.name, _file1_host, _file2_full_path / _dirent.name, _file2_host);
            return result.has_value() && result.value() == 0;
        });
        return result;
    }
    return 0;
}
