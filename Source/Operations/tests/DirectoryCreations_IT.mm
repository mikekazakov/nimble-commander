// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include <VFS/NetFTP.h>
#include "../source/DirectoryCreation/DirectoryCreation.h"
#include "Environment.h"
#include <sys/stat.h>
#include <iostream>

using namespace nc::ops;
using namespace nc::vfs;

#define PREFIX "Operations::DirectoryCreation "

TEST_CASE(PREFIX "Simple creation")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    DirectoryCreation operation{"Test", dir.directory.native(), *host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(host->Exists((dir.directory / "Test").c_str()));
    REQUIRE(host->IsDirectory((dir.directory / "Test").c_str(), 0));
}

TEST_CASE(PREFIX "Multiple directories creation")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    DirectoryCreation operation{"Test1/Test2/Test3", dir.directory.native(), *host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(host->IsDirectory((dir.directory / "Test1").c_str(), 0));
    REQUIRE(host->IsDirectory((dir.directory / "Test1/Test2").c_str(), 0));
    REQUIRE(host->IsDirectory((dir.directory / "Test1/Test2/Test3").c_str(), 0));
}

TEST_CASE(PREFIX "Trailing slashes")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    DirectoryCreation operation{"Test///", dir.directory.native(), *host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(host->IsDirectory((dir.directory / "Test").c_str(), 0));
}

TEST_CASE(PREFIX "Heading slashes")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    DirectoryCreation operation{"///Test", dir.directory.native(), *host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(host->IsDirectory((dir.directory / "Test").c_str(), 0));
}

TEST_CASE(PREFIX "Empty input")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    DirectoryCreation operation{"", dir.directory.native(), *host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
}

TEST_CASE(PREFIX "Weird input")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    DirectoryCreation operation{"!@#$%^&*()_+", dir.directory.native(), *host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(host->IsDirectory((dir.directory / "!@#$%^&*()_+").c_str(), 0));
}

TEST_CASE(PREFIX "Alredy existing dir")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    mkdir((dir.directory / "Test1").c_str(), 0755);
    DirectoryCreation operation{"Test1/Test2/Test3", dir.directory.native(), *host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(host->IsDirectory((dir.directory / "Test1").c_str(), 0));
    REQUIRE(host->IsDirectory((dir.directory / "Test1/Test2").c_str(), 0));
    REQUIRE(host->IsDirectory((dir.directory / "Test1/Test2/Test3").c_str(), 0));
}

TEST_CASE(PREFIX "Alredy existing reg file")
{
    const TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    close(creat((dir.directory / "Test1").c_str(), 0755));
    DirectoryCreation operation{"Test1/Test2/Test3", dir.directory.native(), *host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() != OperationState::Completed);
    REQUIRE(host->Exists((dir.directory / "Test1").c_str()));
    REQUIRE(!host->IsDirectory((dir.directory / "Test1").c_str(), 0));
    REQUIRE(!host->Exists((dir.directory / "Test1/Test2").c_str()));
    REQUIRE(!host->Exists((dir.directory / "Test1/Test2/Test3").c_str()));
}

TEST_CASE(PREFIX "On local FTP server")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<nc::vfs::FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));

    {
        DirectoryCreation operation("/Public/!FilesTesting/Dir/Other/Dir/And/Many/other fancy dirs/", "/", *host);
        operation.Start();
        operation.Wait();
    }

    REQUIRE(host->Stat("/Public/!FilesTesting/Dir/Other/Dir/And/Many/other fancy dirs/", 0));
    REQUIRE(VFSEasyDelete("/Public/!FilesTesting/Dir", host));

    {
        DirectoryCreation operation("AnotherDir/AndSecondOne", "/Public/!FilesTesting", *host);
        operation.Start();
        operation.Wait();
    }

    REQUIRE(host->Stat("/Public/!FilesTesting/AnotherDir/AndSecondOne", 0));
    REQUIRE(VFSEasyDelete("/Public/!FilesTesting/AnotherDir", host));
}
