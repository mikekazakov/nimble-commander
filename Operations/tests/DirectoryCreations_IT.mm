// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include <VFS/NetFTP.h>
#include "../source/DirectoryCreation/DirectoryCreation.h"
#include "Environment.h"
#include <sys/stat.h>

static const auto g_LocalFTP = NCE(nc::env::test::ftp_qnap_nas_host);

using namespace nc::ops;
using namespace nc::vfs;

#define PREFIX "Operations::DirectoryCreation "

TEST_CASE(PREFIX "Simple creation")
{
    TempTestDir dir;
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
    TempTestDir dir;
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
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    DirectoryCreation operation{"Test///", dir.directory.native(), *host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(host->IsDirectory((dir.directory / "Test").c_str(), 0));
}

TEST_CASE(PREFIX "Heading slashes")
{
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    DirectoryCreation operation{"///Test", dir.directory.native(), *host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(host->IsDirectory((dir.directory / "Test").c_str(), 0));
}

TEST_CASE(PREFIX "Empty input")
{
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    DirectoryCreation operation{"", dir.directory.native(), *host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
}

TEST_CASE(PREFIX "Weird input")
{
    TempTestDir dir;
    const auto host = TestEnv().vfs_native;
    DirectoryCreation operation{"!@#$%^&*()_+", dir.directory.native(), *host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(host->IsDirectory((dir.directory / "!@#$%^&*()_+").c_str(), 0));
}

TEST_CASE(PREFIX "Alredy existing dir")
{
    TempTestDir dir;
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
    TempTestDir dir;
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

TEST_CASE(PREFIX "On lLocal FTP server")
{
    VFSHostPtr host;
    try {
        host = std::make_shared<FTPHost>(g_LocalFTP, "", "", "/");
    } catch( VFSErrorException &e ) {
        std::cout << "Skipping test, host not reachable: " << g_LocalFTP << std::endl;
        return;
    }

    {
        DirectoryCreation operation(
            "/Public/!FilesTesting/Dir/Other/Dir/And/Many/other fancy dirs/", "/", *host);
        operation.Start();
        operation.Wait();
    }

    VFSStat st;
    REQUIRE(host->Stat(
                "/Public/!FilesTesting/Dir/Other/Dir/And/Many/other fancy dirs/", st, 0, 0) == 0);
    REQUIRE(VFSEasyDelete("/Public/!FilesTesting/Dir", host) == 0);

    {
        DirectoryCreation operation("AnotherDir/AndSecondOne", "/Public/!FilesTesting", *host);
        operation.Start();
        operation.Wait();
    }

    REQUIRE(host->Stat("/Public/!FilesTesting/AnotherDir/AndSecondOne", st, 0, 0) == 0);
    REQUIRE(VFSEasyDelete("/Public/!FilesTesting/AnotherDir", host) == 0);
}
