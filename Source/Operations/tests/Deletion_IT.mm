// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include <VFS/NetFTP.h>
#include "../source/Deletion/Deletion.h"
#include "Environment.h"
#include <sys/stat.h>
#include <iostream>

using namespace nc;
using namespace nc::ops;

#define PREFIX "Operations::Deletion "

static std::vector<VFSListingItem>
FetchItems(const std::string &_directory_path, const std::vector<std::string> &_filenames, VFSHost &_host);

TEST_CASE(PREFIX "Regular removal")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    close(creat((dir.directory / "regular_file").c_str(), 0755));

    Deletion operation{FetchItems(dir.directory.native(), {"regular_file"}, *host), DeletionType::Permanent};
    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(!host->Exists((dir.directory / "regular_file").c_str()));
}

TEST_CASE(PREFIX "Regular file removal - locked file")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    const auto path = dir.directory / "regular_file";
    REQUIRE(close(creat(path.c_str(), 0755)) == 0);
    REQUIRE(chflags(path.c_str(), UF_IMMUTABLE) == 0);
    DeletionOptions options;
    auto set_type = [&]() {
        SECTION("Permanent")
        {
            options.type = DeletionType::Permanent;
        }
        SECTION("Trash")
        {
            options.type = DeletionType::Trash;
        }
    };
    SECTION("Default: ask => fail")
    {
        set_type();
        Deletion operation{FetchItems(dir.directory.native(), {"regular_file"}, *host), options};
        operation.Start();
        operation.Wait();
        REQUIRE(operation.State() == OperationState::Stopped);
        REQUIRE(host->Exists(path.c_str()));
        REQUIRE(chflags(path.c_str(), 0) == 0);
    }
    SECTION("Skip: skipped")
    {
        set_type();
        options.locked_items_behaviour = DeletionOptions::LockedItemBehavior::SkipAll;
        Deletion operation{FetchItems(dir.directory.native(), {"regular_file"}, *host), options};
        operation.Start();
        operation.Wait();
        REQUIRE(operation.State() == OperationState::Completed);
        REQUIRE(host->Exists(path.c_str()));
        REQUIRE(chflags(path.c_str(), 0) == 0);
    }
    SECTION("Unlock: removed")
    {
        set_type();
        options.locked_items_behaviour = DeletionOptions::LockedItemBehavior::UnlockAll;
        Deletion operation{FetchItems(dir.directory.native(), {"regular_file"}, *host), options};
        operation.Start();
        operation.Wait();
        REQUIRE(operation.State() == OperationState::Completed);
        REQUIRE(!host->Exists(path.c_str()));
    }
}

TEST_CASE(PREFIX "Directory removal - locked file")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    const auto path = dir.directory / "directory";
    REQUIRE_NOTHROW(std::filesystem::create_directory(path));
    REQUIRE(chflags(path.c_str(), UF_IMMUTABLE) == 0);
    DeletionOptions options;
    auto set_type = [&]() {
        SECTION("Permanent")
        {
            options.type = DeletionType::Permanent;
        }
        SECTION("Trash")
        {
            options.type = DeletionType::Trash;
        }
    };
    SECTION("Default: ask => fail")
    {
        set_type();
        Deletion operation{FetchItems(dir.directory.native(), {"directory"}, *host), options};
        operation.Start();
        operation.Wait();
        REQUIRE(operation.State() == OperationState::Stopped);
        REQUIRE(host->Exists(path.c_str()));
        REQUIRE(chflags(path.c_str(), 0) == 0);
    }
    SECTION("Skip: skipped")
    {
        set_type();
        options.locked_items_behaviour = DeletionOptions::LockedItemBehavior::SkipAll;
        Deletion operation{FetchItems(dir.directory.native(), {"directory"}, *host), options};
        operation.Start();
        operation.Wait();
        REQUIRE(operation.State() == OperationState::Completed);
        REQUIRE(host->Exists(path.c_str()));
        REQUIRE(chflags(path.c_str(), 0) == 0);
    }
    SECTION("Unlock: removed")
    {
        set_type();
        options.locked_items_behaviour = DeletionOptions::LockedItemBehavior::UnlockAll;
        Deletion operation{FetchItems(dir.directory.native(), {"directory"}, *host), options};
        operation.Start();
        operation.Wait();
        REQUIRE(operation.State() == OperationState::Completed);
        REQUIRE(!host->Exists(path.c_str()));
    }
}

TEST_CASE(PREFIX "Symlink removal - locked file")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    const auto path = dir.directory / "symlink";
    REQUIRE_NOTHROW(std::filesystem::create_symlink("/bin/sh", path));
    REQUIRE(lchflags(path.c_str(), UF_IMMUTABLE) == 0);
    DeletionOptions options;
    auto set_type = [&]() {
        SECTION("Permanent")
        {
            options.type = DeletionType::Permanent;
        }
        SECTION("Trash")
        {
            options.type = DeletionType::Trash;
        }
    };
    SECTION("Default: ask => fail")
    {
        set_type();
        Deletion operation{FetchItems(dir.directory.native(), {"symlink"}, *host), options};
        operation.Start();
        operation.Wait();
        REQUIRE(operation.State() == OperationState::Stopped);
        REQUIRE(host->Exists(path.c_str()));
        REQUIRE(lchflags(path.c_str(), 0) == 0);
    }
    SECTION("Skip: skipped")
    {
        set_type();
        options.locked_items_behaviour = DeletionOptions::LockedItemBehavior::SkipAll;
        Deletion operation{FetchItems(dir.directory.native(), {"symlink"}, *host), options};
        operation.Start();
        operation.Wait();
        REQUIRE(operation.State() == OperationState::Completed);
        REQUIRE(host->Exists(path.c_str()));
        REQUIRE(lchflags(path.c_str(), 0) == 0);
    }
    SECTION("Unlock: removed")
    {
        set_type();
        options.locked_items_behaviour = DeletionOptions::LockedItemBehavior::UnlockAll;
        Deletion operation{FetchItems(dir.directory.native(), {"symlink"}, *host), options};
        operation.Start();
        operation.Wait();
        REQUIRE(operation.State() == OperationState::Completed);
        REQUIRE(!host->Exists(path.c_str()));
    }
}

TEST_CASE(PREFIX "Directory removal")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    mkdir((dir.directory / "directory").c_str(), 0755);

    Deletion operation{FetchItems(dir.directory.native(), {"directory"}, *host), DeletionType::Permanent};
    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(!host->Exists((dir.directory / "directory").c_str()));
}

TEST_CASE(PREFIX "Link removal")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    link((dir.directory / "link").c_str(), "/System/Library/Kernels/kernel");

    Deletion operation{FetchItems(dir.directory.native(), {"link"}, *host), DeletionType::Permanent};
    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(!host->Exists((dir.directory / "link").c_str()));
}

TEST_CASE(PREFIX "Nested removal")
{
    const TempTestDir dir;
    auto &d = dir.directory;
    const auto host = TestEnv().vfs_native;
    mkdir((d / "top").c_str(), 0755);
    mkdir((d / "top/next1").c_str(), 0755);
    close(creat((d / "top/next1/reg1").c_str(), 0755));
    close(creat((d / "top/next1/reg2").c_str(), 0755));
    mkdir((d / "top/next2").c_str(), 0755);
    close(creat((d / "top/next2/reg1").c_str(), 0755));
    close(creat((d / "top/next2/reg2").c_str(), 0755));

    Deletion operation{FetchItems(d.native(), {"top"}, *host), DeletionType::Permanent};
    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(!host->Exists((d / "top").c_str()));
}

TEST_CASE(PREFIX "Nested trash")
{
    const TempTestDir dir;
    auto &d = dir.directory;
    const auto host = TestEnv().vfs_native;
    mkdir((d / "top").c_str(), 0755);
    mkdir((d / "top/next1").c_str(), 0755);
    close(creat((d / "top/next1/reg1").c_str(), 0755));
    close(creat((d / "top/next1/reg2").c_str(), 0755));
    mkdir((d / "top/next2").c_str(), 0755);
    close(creat((d / "top/next2/reg1").c_str(), 0755));
    close(creat((d / "top/next2/reg2").c_str(), 0755));

    Deletion operation{FetchItems(d.native(), {"top"}, *host), DeletionType::Trash};
    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(!host->Exists((d / "top").c_str()));
}

TEST_CASE(PREFIX "Failing removal")
{
    Deletion operation{FetchItems("/System/Library/Kernels", {"kernel"}, *TestEnv().vfs_native),
                       DeletionType::Permanent};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() != OperationState::Completed);
}

TEST_CASE(PREFIX "Complex deletion")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    REQUIRE(VFSEasyCopyNode("/System/Applications/Mail.app", host, (dir.directory / "Mail.app").c_str(), host) == 0);

    Deletion operation{FetchItems(dir.directory.native(), {"Mail.app"}, *host), DeletionType::Permanent};
    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(!host->Exists((dir.directory / "Mail.app").c_str()));
}

TEST_CASE(PREFIX "Simple delete from FTP")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<nc::vfs::FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));

    const char *fn1 = "/System/Library/Kernels/kernel";
    const char *fn2 = "/Public/!FilesTesting/mach_kernel";
    std::ignore = host->CreateDirectory("/Public", 0755);
    std::ignore = host->CreateDirectory("/Public/!FilesTesting", 0755);

    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2, 0) )
        REQUIRE(host->Unlink(fn2));
    REQUIRE(VFSEasyCopyFile(fn1, TestEnv().vfs_native, fn2, host) == 0);

    Deletion operation{FetchItems("/Public/!FilesTesting", {"mach_kernel"}, *host), DeletionType::Permanent};
    operation.Start();
    operation.Wait();

    REQUIRE(!host->Stat(fn2, 0)); // check that file has gone

    std::ignore = VFSEasyDelete("/Public/!FilesTesting", host);
}

TEST_CASE(PREFIX "Deleting from FTP directory")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<nc::vfs::FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));

    const char *fn1 = "/bin";
    const char *fn2 = "/Public/!FilesTesting/bin";
    std::ignore = host->CreateDirectory("/Public", 0755);
    std::ignore = host->CreateDirectory("/Public/!FilesTesting", 0755);

    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2, 0) )
        REQUIRE(VFSEasyDelete(fn2, host));
    REQUIRE(VFSEasyCopyNode(fn1, TestEnv().vfs_native, fn2, host) == 0);

    Deletion operation{FetchItems("/Public/!FilesTesting", {"bin"}, *host), DeletionType::Permanent};
    operation.Start();
    operation.Wait();

    REQUIRE(!host->Stat(fn2, 0)); // check that file has gone

    std::ignore = VFSEasyDelete("/Public/!FilesTesting", host);
}

static std::vector<VFSListingItem>
FetchItems(const std::string &_directory_path, const std::vector<std::string> &_filenames, VFSHost &_host)
{
    return _host.FetchFlexibleListingItems(_directory_path, _filenames, 0).value_or(std::vector<VFSListingItem>{});
}
