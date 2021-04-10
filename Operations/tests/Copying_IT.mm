// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <Operations/Copying.h>
#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include <VFS/XAttr.h>
#include <VFS/NetFTP.h>
#include <Habanero/algo.h>
#include <set>
#include <span>

using nc::ops::Copying;
using nc::ops::CopyingOptions;
using nc::ops::OperationState;
using nc::utility::NativeFSManager;
static const auto g_LocalFTP = NCE(nc::env::test::ftp_qnap_nas_host);

static std::vector<std::byte> MakeNoise(size_t _size);
static bool Save(const std::filesystem::path &_filepath, std::span<const std::byte> _content);
static int VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                             const VFSHostPtr &_file1_host,
                             const std::filesystem::path &_file2_full_path,
                             const VFSHostPtr &_file2_host,
                             int &_result);
static std::vector<VFSListingItem> FetchItems(const std::string &_directory_path,
                                              const std::vector<std::string> &_filenames,
                                              VFSHost &_host)
{
    std::vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
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
    TempTestDir test_dir;
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

    TempTestDir test_dir;

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

    TempTestDir test_dir;

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

    TempTestDir test_dir;

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

    TempTestDir test_dir;

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

    TempTestDir test_dir;

    REQUIRE(close(creat((test_dir.directory / filename_src).c_str(), 0755)) == 0);

    struct stat orig_stat;
    REQUIRE(stat((test_dir.directory / filename_src).c_str(), &orig_stat) == 0);

    CopyingOptions opts;
    opts.docopy = false;

    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename_src}, *host),
               target_dir + filename_dst,
               host,
               opts);
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

    TempTestDir test_dir;

    REQUIRE(close(creat((test_dir.directory / filename).c_str(), 0755)) == 0);

    struct stat orig_stat;
    REQUIRE(stat((test_dir.directory / filename).c_str(), &orig_stat) == 0);

    CopyingOptions opts;
    opts.docopy = false;

    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename}, *host),
               test_dir.directory / target_dir / filename,
               host,
               opts);
    RunOperationAndCheckSuccess(op);

    struct stat renamed_stat;
    REQUIRE(stat((test_dir.directory / target_dir / filename).c_str(), &renamed_stat) == 0);

    // Verify that the file was renamed instead of copied+deleted
    CHECK(renamed_stat.st_dev == orig_stat.st_dev);
    CHECK(renamed_stat.st_ino == orig_stat.st_ino);
}

TEST_CASE(PREFIX "Reports item status")
{
    TempTestDir test_dir;
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
    TempTestDir tmp_dir;
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

    int result = -1;
    REQUIRE(VFSEasyCompareFiles(
                (tmp_dir.directory / "big.zzz").c_str(), host, dest.c_str(), host, result) == 0);
    REQUIRE(result == 0);

    {
        CopyingOptions opts;
        opts.docopy = true;
        opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
        Copying op(FetchItems(tmp_dir.directory, {"small.zzz"}, *host), dest, host, opts);
        op.Start();
        op.Wait();
    }

    REQUIRE(VFSEasyCompareFiles(
                (tmp_dir.directory / "small.zzz").c_str(), host, dest.c_str(), host, result) == 0);
    REQUIRE(result == 0);
}

TEST_CASE(PREFIX "Overwrite bug regression - revert")
{
    // ensures no-return of a bug introduced 30/01/15
    TempTestDir tmp_dir;
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

    int result = -1;
    REQUIRE(VFSEasyCompareFiles(
                (tmp_dir.directory / "small.zzz").c_str(), host, dest.c_str(), host, result) == 0);
    REQUIRE(result == 0);

    {
        CopyingOptions opts;
        opts.docopy = true;
        opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
        Copying op(FetchItems(tmp_dir.directory, {"big.zzz"}, *host), dest, host, opts);
        op.Start();
        op.Wait();
    }

    REQUIRE(VFSEasyCompareFiles(
                (tmp_dir.directory / "big.zzz").c_str(), host, dest.c_str(), host, result) == 0);
    REQUIRE(result == 0);
}

TEST_CASE(PREFIX "case renaming")
{
    TempTestDir tmp_dir;
    const auto host = TestEnv().vfs_native;
    const auto dir = tmp_dir.directory;

    {
        const auto src = dir / "directory";
        mkdir(src.c_str(), S_IWUSR | S_IXUSR | S_IRUSR);

        CopyingOptions opts;
        opts.docopy = false;
        Copying op(FetchItems(dir.native(), {"directory"}, *host),
                   (dir / "DIRECTORY").native(),
                   host,
                   opts);
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
        Copying op(
            FetchItems(dir.native(), {"filename"}, *host), (dir / "FILENAME").native(), host, opts);

        op.Start();
        op.Wait();

        REQUIRE(host->Exists((dir / "FILENAME").c_str()) == true);
        REQUIRE(FetchItems(dir.native(), {"FILENAME"}, *host).front().Filename() == "FILENAME");
    }
}

TEST_CASE(PREFIX "Modes - CopyToPrefix")
{
    TempTestDir tmp_dir;
    const auto host = TestEnv().vfs_native;
    CopyingOptions opts;
    Copying op(FetchItems("/System/Applications/", {"Mail.app"}, *TestEnv().vfs_native),
               tmp_dir.directory,
               host,
               opts);

    op.Start();
    op.Wait();

    int result = 0;
    REQUIRE(VFSCompareEntries(std::filesystem::path("/System/Applications") / "Mail.app",
                              TestEnv().vfs_native,
                              tmp_dir.directory / "Mail.app",
                              TestEnv().vfs_native,
                              result) == 0);
    REQUIRE(result == 0);
}

TEST_CASE(PREFIX "Modes - CopyToPrefix, with absent directories in path")
{
    TempTestDir tmp_dir;
    const auto host = TestEnv().vfs_native;

    // just like above, but file copy operation should build a destination path
    const auto dst_dir = tmp_dir.directory / "Some" / "Absent" / "Dir" / "Is" / "Here/";

    CopyingOptions opts;
    Copying op(FetchItems("/System/Applications/", {"Mail.app"}, *TestEnv().vfs_native),
               dst_dir.native(),
               host,
               opts);

    op.Start();
    op.Wait();

    int result = 0;
    REQUIRE(VFSCompareEntries(std::filesystem::path("/System/Applications") / "Mail.app",
                              TestEnv().vfs_native,
                              dst_dir / "Mail.app",
                              TestEnv().vfs_native,
                              result) == 0);
    REQUIRE(result == 0);
}

// this test is now actually outdated, since FileCopyOperation now requires that destination path is
// absolute
TEST_CASE(PREFIX "Modes - CopyToPrefix_WithLocalDir")
{
    TempTestDir tmp_dir;
    auto host = TestEnv().vfs_native;

    REQUIRE(VFSEasyCopyNode("/System/Applications/Mail.app",
                            host,
                            (tmp_dir.directory / "Mail.app").c_str(),
                            host) == 0);

    CopyingOptions opts;
    Copying op(FetchItems(tmp_dir.directory, {"Mail.app"}, *TestEnv().vfs_native),
               tmp_dir.directory / "SomeDirectoryName/",
               host,
               opts);

    op.Start();
    op.Wait();

    int result = 0;
    REQUIRE(VFSCompareEntries("/System/Applications/Mail.app",
                              host,
                              tmp_dir.directory / "SomeDirectoryName" / "Mail.app",
                              host,
                              result) == 0);
    REQUIRE(result == 0);
}

// this test is now somewhat outdated, since FileCopyOperation now requires that destination path is
// absolute
TEST_CASE(PREFIX "Modes - CopyToPathName_WithLocalDir")
{
    // Copies "Mail.app" to "Mail2.app" in the same dir
    TempTestDir tmp_dir;
    auto host = TestEnv().vfs_native;

    REQUIRE(VFSEasyCopyNode("/System/Applications/Mail.app",
                            host,
                            (tmp_dir.directory / "Mail.app").c_str(),
                            host) == 0);

    Copying op(FetchItems(tmp_dir.directory, {"Mail.app"}, *TestEnv().vfs_native),
               tmp_dir.directory / "Mail2.app",
               host,
               {});

    op.Start();
    op.Wait();

    int result = 0;
    REQUIRE(
        VFSCompareEntries(
            "/System/Applications/Mail.app", host, tmp_dir.directory / "Mail2.app", host, result) ==
        0);
    REQUIRE(result == 0);
}

TEST_CASE(PREFIX "Modes - RenameToPathPreffix")
{
    // works on single host - In and Out same as where source files are
    // Copies "Mail.app" to "Mail2.app" in the same dir
    TempTestDir tmp_dir;
    auto dir2 =
        tmp_dir.directory / "Some" / "Dir" / "Where" / "Files" / "Should" / "Be" / "Renamed/";
    auto host = TestEnv().vfs_native;

    REQUIRE(VFSEasyCopyNode("/System/Applications/Mail.app",
                            host,
                            (tmp_dir.directory / "Mail.app").c_str(),
                            host) == 0);

    CopyingOptions opts;
    opts.docopy = false;
    Copying op(FetchItems(tmp_dir, {"Mail.app"}, *host), dir2.native(), host, opts);
    op.Start();
    op.Wait();

    int result = 0;
    REQUIRE(VFSCompareEntries(
                "/System/Applications/Mail.app", host, dir2 / "Mail.app", host, result) == 0);
    REQUIRE(result == 0);
}

TEST_CASE(PREFIX "Modes - RenameToPathName")
{
    // works on single host - In and Out same as where source files are
    // Copies "Mail.app" to "Mail2.app" in the same dir
    TempTestDir tmp_dir;
    auto host = TestEnv().vfs_native;

    REQUIRE(VFSEasyCopyNode("/System/Applications/Mail.app",
                            host,
                            (tmp_dir.directory / "Mail.app").c_str(),
                            host) == 0);

    CopyingOptions opts;
    opts.docopy = false;
    Copying op(
        FetchItems(tmp_dir, {"Mail.app"}, *host), tmp_dir.directory / "Mail2.app", host, opts);
    op.Start();
    op.Wait();

    int result = 0;
    REQUIRE(
        VFSCompareEntries(
            "/System/Applications/Mail.app", host, tmp_dir.directory / "Mail2.app", host, result) ==
        0);
    REQUIRE(result == 0);
}

TEST_CASE(PREFIX "symlinks overwriting")
{
    TempTestDir tmp_dir;
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
    TempTestDir tmp_dir;
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
    REQUIRE(std::filesystem::read_symlink(tmp_dir.directory / "D1" / "symlink") ==
            "new_symlink_value");
}

TEST_CASE(PREFIX "symlink renaming")
{
    TempTestDir tmp_dir;
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
    TempTestDir tmp_dir;
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    mkdir((tmp_dir.directory / "DirA" / "TestDir").c_str(), 0755);
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    mkdir((tmp_dir.directory / "DirB" / "TestDir").c_str(), 0755);
    chflags((tmp_dir.directory / "DirB" / "TestDir").c_str(), UF_HIDDEN);
    close(open((tmp_dir.directory / "DirB" / "TestDir" / "file.txt").c_str(),
               O_WRONLY | O_CREAT,
               S_IWUSR | S_IRUSR));

    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteOld;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"TestDir"}, *host),
               tmp_dir.directory / "DirA",
               host,
               opts);

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
    TempTestDir tmp_dir;
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    close(
        open((tmp_dir.directory / "DirA" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    mkdir((tmp_dir.directory / "DirB" / "item").c_str(), 0755);

    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"item"}, *host),
               tmp_dir.directory / "DirA",
               host,
               opts);

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
    TempTestDir tmp_dir;
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    close(
        open((tmp_dir.directory / "DirA" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    mkdir((tmp_dir.directory / "DirB" / "item").c_str(), 0755);
    close(open((tmp_dir.directory / "DirB" / "item" / "test").c_str(),
               O_WRONLY | O_CREAT,
               S_IWUSR | S_IRUSR));

    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"item"}, *host),
               tmp_dir.directory / "DirA",
               host,
               opts);

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
    TempTestDir tmp_dir;
    CopyingOptions opts;
    opts.docopy = true;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems("/System/Applications", {"Mail.app"}, *host), tmp_dir, host, opts);
    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    const auto command =
        "/usr/bin/codesign --verify --no-strict " + (tmp_dir.directory / "Mail.app").native();
    REQUIRE(system(command.c_str()) == 0);
}

TEST_CASE(PREFIX "copying to existing item with KeepBoth results in orig copied with another name")
{
    TempTestDir tmp_dir;
    // DirA/item (file)
    // DirB/item (file)
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    close(
        open((tmp_dir.directory / "DirA" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    close(
        open((tmp_dir.directory / "DirB" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));

    CopyingOptions opts;
    opts.docopy = true;
    opts.exist_behavior = CopyingOptions::ExistBehavior::KeepBoth;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"item"}, *host),
               tmp_dir.directory / "DirA",
               host,
               opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirA" / "item 2").type() ==
            std::filesystem::file_type::regular);
}

TEST_CASE(PREFIX
          "renaming to existing item with KeepiBoth results in orig rename with another name")
{
    TempTestDir tmp_dir;
    // DirA/item (file)
    // DirB/item (file)
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    close(
        open((tmp_dir.directory / "DirA" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    close(
        open((tmp_dir.directory / "DirB" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));

    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::KeepBoth;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"item"}, *host),
               tmp_dir.directory / "DirA",
               host,
               opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirA" / "item 2").type() ==
            std::filesystem::file_type::regular);
    REQUIRE(std::filesystem::status(tmp_dir.directory / "DirB" / "item").type() ==
            std::filesystem::file_type::not_found);
}

TEST_CASE(PREFIX
          "copying symlink to existing item with KeepBoth results in orig copied with another name")
{
    TempTestDir tmp_dir;
    // DirA/item (file)
    // DirB/item (simlink)
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    close(
        open((tmp_dir.directory / "DirA" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    symlink("something", (tmp_dir.directory / "DirB" / "item").c_str());

    CopyingOptions opts;
    opts.docopy = true;
    opts.exist_behavior = CopyingOptions::ExistBehavior::KeepBoth;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"item"}, *host),
               tmp_dir.directory / "DirA",
               host,
               opts);

    op.Start();
    op.Wait();
    REQUIRE(op.State() == OperationState::Completed);
    REQUIRE(std::filesystem::symlink_status(tmp_dir.directory / "DirA" / "item 2").type() ==
            std::filesystem::file_type::symlink);
}

TEST_CASE(
    PREFIX
    "renaming symlink to existing item with KeepBoth results in orig renamed with Another name")
{
    TempTestDir tmp_dir;
    // DirA/item (file)
    // DirB/item (symink)
    mkdir((tmp_dir.directory / "DirA").c_str(), 0755);
    close(
        open((tmp_dir.directory / "DirA" / "item").c_str(), O_WRONLY | O_CREAT, S_IWUSR | S_IRUSR));
    mkdir((tmp_dir.directory / "DirB").c_str(), 0755);
    symlink("something", (tmp_dir.directory / "DirB" / "item").c_str());

    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::KeepBoth;
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(tmp_dir.directory / "DirB", {"item"}, *host),
               tmp_dir.directory / "DirA",
               host,
               opts);

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
    TempTestDir tmp_dir;

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

        int result = 0;
        REQUIRE(VFSEasyCompareFiles(orig.c_str(), native_host, "/src", src_host, result) == 0);
        REQUIRE(result == 0);
    }

    const auto xattr2 = tmp_dir.directory / "xattr2";
    fclose(fopen(xattr2.c_str(), "w"));
    const VFSHostPtr dst_host = std::make_shared<nc::vfs::XAttrHost>(xattr2.c_str(), native_host);
    {
        Copying op(FetchItems("/", {"src"}, *src_host), "/dst", dst_host, {});
        op.Start();
        op.Wait();

        int result = 0;
        REQUIRE(VFSEasyCompareFiles(orig.c_str(), native_host, "/dst", dst_host, result) == 0);
        REQUIRE(result == 0);
    }
}

TEST_CASE(PREFIX "Copy to local FTP, part1")
{
    VFSHostPtr host = std::make_shared<nc::vfs::FTPHost>(g_LocalFTP, "", "", "/");

    const char *fn1 = "/System/Library/Kernels/kernel", *fn2 = "/Public/!FilesTesting/kernel";

    VFSEasyDelete(fn2, host);

    CopyingOptions opts;
    Copying op(FetchItems("/System/Library/Kernels/", {"kernel"}, *TestEnv().vfs_native),
               "/Public/!FilesTesting/",
               host,
               opts);

    op.Start();
    op.Wait();

    int compare;
    REQUIRE(VFSEasyCompareFiles(fn1, TestEnv().vfs_native, fn2, host, compare) == 0);
    REQUIRE(compare == 0);

    REQUIRE(host->Unlink(fn2, 0) == 0);
}

TEST_CASE(PREFIX "Copy to local FTP, part2")
{
    using namespace std;
    VFSHostPtr host = std::make_shared<nc::vfs::FTPHost>(g_LocalFTP, "", "", "/");

    auto files = {"Info.plist", "PkgInfo", "version.plist"};

    for( auto &i : files )
        VFSEasyDelete(("/Public/!FilesTesting/"s + i).c_str(), host);

    CopyingOptions opts;
    Copying op(FetchItems("/System/Applications/Mail.app/Contents",
                          {begin(files), end(files)},
                          *TestEnv().vfs_native),
               "/Public/!FilesTesting/",
               host,
               opts);

    op.Start();
    op.Wait();

    for( auto &i : files ) {
        int compare;
        REQUIRE(VFSEasyCompareFiles(("/System/Applications/Mail.app/Contents/"s + i).c_str(),
                                    TestEnv().vfs_native,
                                    ("/Public/!FilesTesting/"s + i).c_str(),
                                    host,
                                    compare) == 0);
        REQUIRE(compare == 0);
        REQUIRE(host->Unlink(("/Public/!FilesTesting/"s + i).c_str(), 0) == 0);
    }
}

TEST_CASE(PREFIX "Copy to local FTP, part3")
{
    VFSHostPtr host = std::make_shared<nc::vfs::FTPHost>(g_LocalFTP, "", "", "/");

    VFSEasyDelete("/Public/!FilesTesting/bin", host);

    CopyingOptions opts;
    Copying op(
        FetchItems("/", {"bin"}, *TestEnv().vfs_native), "/Public/!FilesTesting/", host, opts);

    op.Start();
    op.Wait();

    int result = 0;
    REQUIRE(VFSCompareEntries(
                "/bin", TestEnv().vfs_native, "/Public/!FilesTesting/bin", host, result) == 0);
    REQUIRE(result == 0);

    VFSEasyDelete("/Public/!FilesTesting/bin", host);
}

TEST_CASE(PREFIX "Copy to local FTP, part4")
{
    VFSHostPtr host = std::make_shared<nc::vfs::FTPHost>(g_LocalFTP, "", "", "/");

    const char *fn1 = "/System/Library/Kernels/kernel", *fn2 = "/Public/!FilesTesting/kernel",
               *fn3 = "/Public/!FilesTesting/kernel copy";

    VFSEasyDelete(fn2, host);
    VFSEasyDelete(fn3, host);

    {
        Copying op(FetchItems("/System/Library/Kernels/", {"kernel"}, *TestEnv().vfs_native),
                   "/Public/!FilesTesting/",
                   host,
                   {});
        op.Start();
        op.Wait();
    }

    int compare;
    REQUIRE(VFSEasyCompareFiles(fn1, TestEnv().vfs_native, fn2, host, compare) == 0);
    REQUIRE(compare == 0);

    {
        Copying op(FetchItems("/Public/!FilesTesting/", {"kernel"}, *host), fn3, host, {});
        op.Start();
        op.Wait();
    }

    REQUIRE(VFSEasyCompareFiles(fn2, host, fn3, host, compare) == 0);
    REQUIRE(compare == 0);

    REQUIRE(host->Unlink(fn2, 0) == 0);
    REQUIRE(host->Unlink(fn3, 0) == 0);
}

TEST_CASE(PREFIX "Renaming a locked native regular file")
{
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    const auto filename = "regular_file";
    const auto filename_new = "regular_file_2";
    const auto path = dir.directory / filename;
    REQUIRE(close(creat(path.c_str(), 0755)) == 0);
    REQUIRE(chflags(path.c_str(), UF_IMMUTABLE) == 0);

    CopyingOptions opts;
    opts.docopy = false;
    
    std::unique_ptr<Copying> op;
    auto run = [&]{
        op = std::make_unique<Copying>(
            FetchItems(dir.directory, {filename}, *host), dir.directory / filename_new, host, opts);
        op->Start();
        op->Wait();
    };
    SECTION("Default - ask")
    {
        run();
        REQUIRE(op->State() == OperationState::Stopped);
        REQUIRE(host->Exists(path.c_str()));
        REQUIRE(chflags(path.c_str(), 0) == 0);
    }
    SECTION("Default - skip")
    {
        opts.locked_items_behaviour = CopyingOptions::LockedItemBehavior::SkipAll;
        run();
        REQUIRE(op->State() == OperationState::Completed);
        REQUIRE(host->Exists(path.c_str()));
        REQUIRE(chflags(path.c_str(), 0) == 0);
    }
    SECTION("Default - stop")
    {
        opts.locked_items_behaviour = CopyingOptions::LockedItemBehavior::Stop;
        run();
        REQUIRE(op->State() == OperationState::Stopped);
        REQUIRE(host->Exists(path.c_str()));
        REQUIRE(chflags(path.c_str(), 0) == 0);
    }
    SECTION("Default - unlock")
    {
        opts.locked_items_behaviour = CopyingOptions::LockedItemBehavior::UnlockAll;
        run();
        REQUIRE(op->State() == OperationState::Completed);
        REQUIRE(host->Exists(path.c_str()) == false);
        REQUIRE(host->Exists((dir.directory / filename_new).c_str()) == true);
    }
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

static int VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                             const VFSHostPtr &_file1_host,
                             const std::filesystem::path &_file2_full_path,
                             const VFSHostPtr &_file2_host,
                             int &_result)
{
    // TODO: rewrite this!
    // not comparing contents, flags, perm, times, xattrs, acls etc now

    VFSStat st1, st2;
    int ret;
    if( (ret = _file1_host->Stat(_file1_full_path.c_str(), st1, 0, 0)) != 0 )
        return ret;

    if( (ret = _file2_host->Stat(_file2_full_path.c_str(), st2, 0, 0)) != 0 )
        return ret;

    if( (st1.mode & S_IFMT) != (st2.mode & S_IFMT) ) {
        _result = -1;
        return 0;
    }

    if( S_ISREG(st1.mode) ) {
        _result = int(int64_t(st1.size) - int64_t(st2.size));
        return 0;
    }
    else if( S_ISDIR(st1.mode) ) {
        _file1_host->IterateDirectoryListing(
            _file1_full_path.c_str(), [&](const VFSDirEnt &_dirent) {
                int ret = VFSCompareEntries(_file1_full_path / _dirent.name,
                                            _file1_host,
                                            _file2_full_path / _dirent.name,
                                            _file2_host,
                                            _result);
                if( ret != 0 )
                    return false;
                return true;
            });
    }
    return 0;
}
