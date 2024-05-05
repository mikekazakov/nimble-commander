// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include "../source/Linkage/Linkage.h"
#include <VFS/Native.h>
#include <filesystem>

using namespace nc::ops;
using namespace std::literals;

#define PREFIX "Operations::Linkage "

TEST_CASE(PREFIX "symlink creation")
{
    TempTestDir dir;
    const auto host = std::shared_ptr<nc::vfs::Host>(TestEnv().vfs_native);
    const auto path = (std::filesystem::path(dir.directory) / "symlink").native();
    const auto value = "pointing_somewhere"s;
    Linkage operation{path, value, host, LinkageType::CreateSymlink};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);

    VFSStat st;
    const auto st_rc = host->Stat(path.c_str(), st, VFSFlags::F_NoFollow);
    REQUIRE(st_rc == VFSError::Ok);
    REQUIRE((st.mode & S_IFMT) == S_IFLNK);

    char buf[MAXPATHLEN];
    REQUIRE(host->ReadSymlink(path.c_str(), buf, sizeof(buf)) == VFSError::Ok);
    REQUIRE(buf == value);
}

TEST_CASE(PREFIX "symlink creation on invalid path")
{
    TempTestDir dir;
    const auto host = std::shared_ptr<nc::vfs::Host>(TestEnv().vfs_native);
    const auto path = (std::filesystem::path(dir.directory) / "not_existing_directory/symlink").native();
    const auto value = "pointing_somewhere"s;
    Linkage operation{path, value, host, LinkageType::CreateSymlink};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() != OperationState::Completed);
}

TEST_CASE(PREFIX "symlink alteration")
{
    TempTestDir dir;
    const auto host = std::shared_ptr<nc::vfs::Host>(TestEnv().vfs_native);
    const auto path = (std::filesystem::path(dir.directory) / "symlink").native();
    const auto value = "pointing_somewhere"s;
    symlink("previous_symlink_value", path.c_str());

    Linkage operation{path, value, host, LinkageType::AlterSymlink};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);

    VFSStat st;
    const auto st_rc = host->Stat(path.c_str(), st, VFSFlags::F_NoFollow);
    REQUIRE(st_rc == VFSError::Ok);
    REQUIRE((st.mode & S_IFMT) == S_IFLNK);

    char buf[MAXPATHLEN];
    REQUIRE(host->ReadSymlink(path.c_str(), buf, sizeof(buf)) == VFSError::Ok);
    REQUIRE(buf == value);
}

TEST_CASE(PREFIX "hardlink creation")
{
    TempTestDir dir;
    const auto host = std::shared_ptr<nc::vfs::Host>(TestEnv().vfs_native);
    const auto path = (std::filesystem::path(dir.directory) / "node1").native();
    const auto value = (std::filesystem::path(dir.directory) / "node2").native();
    close(creat(value.c_str(), 0755));

    Linkage operation{path, value, host, LinkageType::CreateHardlink};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);

    VFSStat st1, st2;
    REQUIRE(host->Stat(path.c_str(), st1, 0) == VFSError::Ok);
    REQUIRE(host->Stat(value.c_str(), st2, 0) == VFSError::Ok);
    REQUIRE(st1.inode == st2.inode);
}
