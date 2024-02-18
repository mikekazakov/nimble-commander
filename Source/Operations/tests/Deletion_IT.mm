// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
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

static std::vector<VFSListingItem> FetchItems(const std::string &_directory_path,
                                              const std::vector<std::string> &_filenames,
                                              VFSHost &_host);

TEST_CASE(PREFIX "Regular removal")
{
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    close(creat((dir.directory / "regular_file").c_str(), 0755));

    Deletion operation{FetchItems(dir.directory.native(), {"regular_file"}, *host),
                       DeletionType::Permanent};
    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(!host->Exists((dir.directory / "regular_file").c_str()));
}

TEST_CASE(PREFIX "Regular file removal - locked file")
{
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    const auto path = dir.directory / "regular_file";
    REQUIRE(close(creat(path.c_str(), 0755)) == 0);
    REQUIRE(chflags(path.c_str(), UF_IMMUTABLE) == 0);
    DeletionOptions options;
    auto set_type = [&]() {
        SECTION("Permanent") { options.type = DeletionType::Permanent; }
        SECTION("Trash") { options.type = DeletionType::Trash; }
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
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    const auto path = dir.directory / "directory";
    REQUIRE_NOTHROW( std::filesystem::create_directory(path));
    REQUIRE(chflags(path.c_str(), UF_IMMUTABLE) == 0);
    DeletionOptions options;
    auto set_type = [&]() {
        SECTION("Permanent") { options.type = DeletionType::Permanent; }
        SECTION("Trash") { options.type = DeletionType::Trash; }
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
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    const auto path = dir.directory / "symlink";
    REQUIRE_NOTHROW( std::filesystem::create_symlink("/bin/sh", path) );
    REQUIRE(lchflags(path.c_str(), UF_IMMUTABLE) == 0);
    DeletionOptions options;
    auto set_type = [&]() {
        SECTION("Permanent") { options.type = DeletionType::Permanent; }
        SECTION("Trash") { options.type = DeletionType::Trash; }
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
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    mkdir((dir.directory / "directory").c_str(), 0755);

    Deletion operation{FetchItems(dir.directory.native(), {"directory"}, *host),
                       DeletionType::Permanent};
    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(!host->Exists((dir.directory / "directory").c_str()));
}

TEST_CASE(PREFIX "Link removal")
{
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    link((dir.directory / "link").c_str(), "/System/Library/Kernels/kernel");

    Deletion operation{FetchItems(dir.directory.native(), {"link"}, *host),
                       DeletionType::Permanent};
    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(!host->Exists((dir.directory / "link").c_str()));
}

TEST_CASE(PREFIX "Nested removal")
{
    TempTestDir dir;
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
    TempTestDir dir;
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
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    REQUIRE(VFSEasyCopyNode("/System/Applications/Mail.app",
                            host,
                            (dir.directory / "Mail.app").c_str(),
                            host) == 0);

    Deletion operation{FetchItems(dir.directory.native(), {"Mail.app"}, *host),
                       DeletionType::Permanent};
    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(!host->Exists((dir.directory / "Mail.app").c_str()));
}

// Disabled for now
//TEST_CASE(PREFIX "Simple delete from FTP")
//{
//    VFSHostPtr host;
//    try {
//        host = std::make_shared<vfs::FTPHost>(g_LocalFTP, "", "", "/");
//    } catch( VFSErrorException &e ) {
//        std::cout << "Skipping test, host not reachable: " << g_LocalFTP << std::endl;
//        return;
//    }
//
//    const char *fn1 = "/System/Library/Kernels/kernel", *fn2 = "/Public/!FilesTesting/mach_kernel";
//    VFSStat stat;
//    // if there's a trash from previous runs - remove it
//    if( host->Stat(fn2, stat, 0, 0) == 0 )
//        REQUIRE(host->Unlink(fn2, 0) == 0);
//    REQUIRE(VFSEasyCopyFile(fn1, TestEnv().vfs_native, fn2, host) == 0);
//
//    Deletion operation{FetchItems("/Public/!FilesTesting", {"mach_kernel"}, *host),
//                       DeletionType::Permanent};
//    operation.Start();
//    operation.Wait();
//
//    REQUIRE(host->Stat(fn2, stat, 0, 0) != 0); // check that file has gone
//}
//
//TEST_CASE(PREFIX "Deleting from FTP directory")
//{
//    VFSHostPtr host;
//    try {
//        host = std::make_shared<vfs::FTPHost>(g_LocalFTP, "", "", "/");
//    } catch( VFSErrorException &e ) {
//        std::cout << "Skipping test, host not reachable: " << g_LocalFTP << std::endl;
//        return;
//    }
//    const char *fn1 = "/bin", *fn2 = "/Public/!FilesTesting/bin";
//    VFSStat stat;
//
//    // if there's a trash from previous runs - remove it
//    if( host->Stat(fn2, stat, 0, 0) == 0 )
//        REQUIRE(VFSEasyDelete(fn2, host) == 0);
//    REQUIRE(VFSEasyCopyNode(fn1, TestEnv().vfs_native, fn2, host) == 0);
//
//    Deletion operation{FetchItems("/Public/!FilesTesting", {"bin"}, *host),
//                       DeletionType::Permanent};
//    operation.Start();
//    operation.Wait();
//
//    REQUIRE(host->Stat(fn2, stat, 0, 0) != 0); // check that file has gone
//}

static std::vector<VFSListingItem> FetchItems(const std::string &_directory_path,
                                              const std::vector<std::string> &_filenames,
                                              VFSHost &_host)
{
    std::vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}
