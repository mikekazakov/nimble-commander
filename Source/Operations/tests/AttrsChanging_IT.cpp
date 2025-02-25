// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <sys/stat.h>
#include "../source/AttrsChanging/AttrsChanging.h"
#include <VFS/Native.h>
#include <chrono>
#include <set>

using namespace nc;
using namespace nc::ops;
using namespace std::literals;

#define PREFIX "Operations::AttrsChanging "

static std::vector<VFSListingItem>
FetchItems(const std::string &_directory_path, const std::vector<std::string> &_filenames, VFSHost &_host);

TEST_CASE(PREFIX "chmod")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    const auto path = tmp_dir.directory / "test";
    close(creat(path.c_str(), 0755));
    AttrsChangingCommand cmd;
    cmd.items = FetchItems(tmp_dir.directory, {"test"}, *native_host);
    cmd.permissions.emplace();
    cmd.permissions->grp_r = false;
    cmd.permissions->grp_x = false;
    cmd.permissions->oth_r = false;
    cmd.permissions->oth_x = false;

    AttrsChanging operation{cmd};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);

    const VFSStat st = native_host->Stat(path.c_str(), 0).value();
    CHECK((st.mode & ~S_IFMT) == 0700);
}

TEST_CASE(PREFIX "recursion")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    const auto path = tmp_dir.directory / "test";
    const auto path1 = tmp_dir.directory / "test/qwer";
    const auto path2 = tmp_dir.directory / "test/qwer/asdf";
    mkdir(path.c_str(), 0755);
    mkdir(path1.c_str(), 0755);
    close(creat(path2.c_str(), 0755));

    AttrsChangingCommand cmd;
    cmd.items = FetchItems(tmp_dir.directory, {"test"}, *native_host);
    cmd.permissions.emplace();
    cmd.permissions->grp_r = false;
    cmd.permissions->grp_x = false;
    cmd.permissions->oth_r = false;
    cmd.permissions->oth_x = false;
    cmd.apply_to_subdirs = true;

    AttrsChanging operation{cmd};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);

    CHECK((native_host->Stat(path.c_str(), 0).value().mode & ~S_IFMT) == 0700);
    CHECK((native_host->Stat(path1.c_str(), 0).value().mode & ~S_IFMT) == 0700);
    CHECK((native_host->Stat(path2.c_str(), 0).value().mode & ~S_IFMT) == 0700);
}

TEST_CASE(PREFIX "chown")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    const auto path = tmp_dir.directory / "test";
    close(creat(path.c_str(), 0755));
    AttrsChangingCommand cmd;
    cmd.items = FetchItems(tmp_dir.directory, {"test"}, *native_host);
    cmd.ownage.emplace();
    cmd.ownage->gid = 12;
    AttrsChanging operation{cmd};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);

    CHECK(native_host->Stat(path.c_str(), 0).value().gid == 12);
}

TEST_CASE(PREFIX "chflags")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    const auto path = tmp_dir.directory / "test";
    close(creat(path.c_str(), 0755));

    AttrsChangingCommand cmd;
    cmd.items = FetchItems(tmp_dir.directory, {"test"}, *native_host);
    cmd.flags.emplace();
    cmd.flags->u_hidden = true;

    AttrsChanging operation{cmd};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);

    CHECK((native_host->Stat(path.c_str(), 0).value().flags & UF_HIDDEN) != 0);
}

TEST_CASE(PREFIX "mtime")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    const auto path = tmp_dir.directory / "test";
    // now - 10'000 seconds
    const long mtime = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now()) - 10'000;
    close(creat(path.c_str(), 0755));
    AttrsChangingCommand cmd;
    cmd.items = FetchItems(tmp_dir.directory, {"test"}, *native_host);
    cmd.times.emplace();
    cmd.times->mtime = mtime;

    AttrsChanging operation{cmd};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);

    CHECK(native_host->Stat(path.c_str(), 0).value().mtime.tv_sec == mtime);
}

TEST_CASE(PREFIX "Item reporting")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    const auto path = tmp_dir.directory / "test";
    const auto path1 = tmp_dir.directory / "test/dir";
    const auto path2 = tmp_dir.directory / "test/dir/file.txt";
    mkdir(path.c_str(), 0755);
    mkdir(path1.c_str(), 0755);
    close(creat(path2.c_str(), 0755));

    AttrsChangingCommand cmd;
    cmd.items = FetchItems(tmp_dir.directory, {"test"}, *native_host);
    cmd.flags.emplace();
    cmd.flags->u_hidden = true;
    cmd.apply_to_subdirs = true;

    AttrsChanging operation{cmd};
    std::set<std::string> processed;
    operation.SetItemStatusCallback([&](nc::ops::ItemStateReport _report) {
        REQUIRE(&_report.host == native_host.get());
        REQUIRE(_report.status == nc::ops::ItemStatus::Processed);
        processed.emplace(_report.path);
    });
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);

    const std::set<std::string> expected{path, path1, path2};
    CHECK(processed == expected);
}

static std::vector<VFSListingItem>
FetchItems(const std::string &_directory_path, const std::vector<std::string> &_filenames, VFSHost &_host)
{
    return _host.FetchFlexibleListingItems(_directory_path, _filenames, 0).value_or(std::vector<VFSListingItem>{});
}
