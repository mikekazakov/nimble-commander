// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <filesystem>
#include <sys/stat.h>
#include <set>

#include "../source/Compression/Compression.h"
#include "../source/Statistics.h"

#include <VFS/VFS.h>
#include <VFS/ArcLA.h>
#include <VFS/Native.h>

using namespace nc;
using namespace nc::ops;
using namespace std::literals;

#define PREFIX "Operations::Compression "

static int VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                             const VFSHostPtr &_file1_host,
                             const std::filesystem::path &_file2_full_path,
                             const VFSHostPtr &_file2_host,
                             int &_result);

static std::vector<VFSListingItem>
FetchItems(const std::string &_directory_path, const std::vector<std::string> &_filenames, VFSHost &_host);

TEST_CASE(PREFIX "Empty archive building")
{
    TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    Compression operation{std::vector<VFSListingItem>{}, tmp_dir.directory, native_host};
    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath().c_str()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));
    CHECK(arc_host->StatTotalFiles() == 0);
}

TEST_CASE(PREFIX "Compressing Mac kernel")
{
    TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;

    Compression operation{
        FetchItems("/System/Library/Kernels/", {"kernel"}, *native_host), tmp_dir.directory, native_host};

    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    CHECK(operation.Statistics().ElapsedTime() > 1ms);
    CHECK(operation.Statistics().ElapsedTime() < 5s);
    REQUIRE(native_host->Exists(operation.ArchivePath().c_str()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));
    CHECK(arc_host->StatTotalFiles() == 1);
    int cmp_result = 0;
    const auto cmp_rc =
        VFSEasyCompareFiles("/System/Library/Kernels/kernel", native_host, "/kernel", arc_host, cmp_result);
    CHECK(cmp_rc == VFSError::Ok);
    CHECK(cmp_result == 0);
}

TEST_CASE(PREFIX "Compressing Bin utilities")
{
    TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;

    const std::vector<std::string> filenames = {
        "[",        "bash",  "cat", "chmod",     "cp",   "csh",  "date", "dd",    "df",     "echo",      "ed", "expr",
        "hostname", "kill",  "ksh", "launchctl", "link", "ln",   "ls",   "mkdir", "mv",     "pax",       "ps", "pwd",
        "rm",       "rmdir", "sh",  "sleep",     "stty", "sync", "tcsh", "test",  "unlink", "wait4path", "zsh"};

    Compression operation{FetchItems("/bin/", filenames, *native_host), tmp_dir.directory, native_host};

    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath().c_str()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));
    CHECK(arc_host->StatTotalFiles() == filenames.size());

    for( auto &fn : filenames ) {
        int cmp_result = 0;
        const auto cmp_rc =
            VFSEasyCompareFiles(("/bin/"s + fn).c_str(), native_host, ("/"s + fn).c_str(), arc_host, cmp_result);
        CHECK(cmp_rc == VFSError::Ok);
        CHECK(cmp_result == 0);
    }
}

TEST_CASE(PREFIX "Compressing Bin directory")
{
    TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;

    Compression operation{FetchItems("/", {"bin"}, *native_host), tmp_dir.directory, native_host};

    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath().c_str()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));
    int cmp_result = 0;
    const auto cmp_rc = VFSCompareEntries("/bin/", native_host, "/bin/", arc_host, cmp_result);
    CHECK(cmp_rc == VFSError::Ok);
    CHECK(cmp_result == 0);
}

TEST_CASE(PREFIX "Compressing Chess.app")
{
    TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;

    Compression operation{
        FetchItems("/System/Applications/", {"Chess.app"}, *native_host), tmp_dir.directory, native_host};

    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath().c_str()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));

    int cmp_result = 0;
    const auto cmp_rc =
        VFSCompareEntries("/System/Applications/Chess.app", native_host, "/Chess.app", arc_host, cmp_result);
    CHECK(cmp_rc == VFSError::Ok);
    CHECK(cmp_result == 0);
}

TEST_CASE(PREFIX "Compressing kernel into encrypted archive")
{
    TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    const auto passwd = "This is a very secret password";

    Compression operation{
        FetchItems("/System/Library/Kernels/", {"kernel"}, *native_host), tmp_dir.directory, native_host, passwd};

    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath().c_str()));

    try {
        std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host);
        REQUIRE(false);
    } catch( VFSErrorException &e ) {
        REQUIRE(e.code() == VFSError::ArclibPasswordRequired);
    }

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host =
                        std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host, passwd));
    int cmp_result = 0;
    const auto cmp_rc =
        VFSEasyCompareFiles("/System/Library/Kernels/kernel", native_host, "/kernel", arc_host, cmp_result);
    CHECK(cmp_rc == VFSError::Ok);
    CHECK(cmp_result == 0);
}

TEST_CASE(PREFIX "Compressing /bin into encrypted archive")
{
    TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    const auto passwd = "This is a very secret password";

    Compression operation{FetchItems("/", {"bin"}, *native_host), tmp_dir.directory, native_host, passwd};

    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath().c_str()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host =
                        std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host, passwd));
    int cmp_result = 0;
    const auto cmp_rc = VFSCompareEntries("/bin/", native_host, "/bin/", arc_host, cmp_result);
    CHECK(cmp_rc == VFSError::Ok);
    CHECK(cmp_result == 0);
}

TEST_CASE(PREFIX "Long compression stats (compressing Music.app)")
{
    TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    Compression operation{
        FetchItems("/System/Applications/", {"Music.app"}, *native_host), tmp_dir.directory, native_host};

    operation.Start();
    operation.Wait(1000ms);
    const auto eta = operation.Statistics().ETA(Statistics::SourceType::Bytes);
    REQUIRE(eta);
    CHECK(*eta > std::chrono::milliseconds(1000));

    operation.Pause();
    REQUIRE(operation.State() == OperationState::Paused);
    operation.Wait(5000ms);
    REQUIRE(operation.State() == OperationState::Paused);
    operation.Resume();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath().c_str()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));
    int cmp_result = 0;
    const auto cmp_rc =
        VFSCompareEntries("/System/Applications/Music.app", native_host, "/Music.app", arc_host, cmp_result);
    CHECK(cmp_rc == VFSError::Ok);
    CHECK(cmp_result == 0);
}

TEST_CASE(PREFIX "Item reporting")
{
    TempTestDir tmp_dir;
    REQUIRE(mkdir((tmp_dir.directory / "dir").c_str(), 0755) == 0);
    REQUIRE(close(creat((tmp_dir.directory / "dir/f1").c_str(), 0755)) == 0);
    REQUIRE(symlink("./f1", (tmp_dir.directory / "dir/f2").c_str()) == 0);
    const auto native_host = TestEnv().vfs_native;
    Compression operation{FetchItems(tmp_dir.directory, {"dir"}, *native_host), tmp_dir.directory, native_host};
    std::set<std::string> processed;
    operation.SetItemStatusCallback([&](nc::ops::ItemStateReport _report) {
        REQUIRE(&_report.host == native_host.get());
        REQUIRE(_report.status == nc::ops::ItemStatus::Processed);
        processed.emplace(_report.path);
    });

    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);

    const std::set<std::string> expected{
        tmp_dir.directory / "dir", tmp_dir.directory / "dir/f1", tmp_dir.directory / "dir/f2"};
    CHECK(processed == expected);
}

static int VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                             const VFSHostPtr &_file1_host,
                             const std::filesystem::path &_file2_full_path,
                             const VFSHostPtr &_file2_host,
                             int &_result)
{
    // not comparing flags, perm, times, xattrs, acls etc now

    VFSStat st1, st2;
    int ret;
    if( (ret = _file1_host->Stat(_file1_full_path.c_str(), st1, VFSFlags::F_NoFollow, 0)) < 0 )
        return ret;

    if( (ret = _file2_host->Stat(_file2_full_path.c_str(), st2, VFSFlags::F_NoFollow, 0)) < 0 )
        return ret;

    if( (st1.mode & S_IFMT) != (st2.mode & S_IFMT) ) {
        _result = -1;
        return 0;
    }

    if( S_ISREG(st1.mode) ) {
        if( int64_t(st1.size) - int64_t(st2.size) != 0 )
            _result = int(int64_t(st1.size) - int64_t(st2.size));
    }
    else if( S_ISLNK(st1.mode) ) {
        char link1[MAXPATHLEN], link2[MAXPATHLEN];
        if( (ret = _file1_host->ReadSymlink(_file1_full_path.c_str(), link1, MAXPATHLEN, 0)) < 0 )
            return ret;
        if( (ret = _file2_host->ReadSymlink(_file2_full_path.c_str(), link2, MAXPATHLEN, 0)) < 0 )
            return ret;
        if( strcmp(link1, link2) != 0 )
            _result = strcmp(link1, link2);
    }
    else if( S_ISDIR(st1.mode) ) {
        _file1_host->IterateDirectoryListing(_file1_full_path.c_str(), [&](const VFSDirEnt &_dirent) {
            int ret = VFSCompareEntries(
                _file1_full_path / _dirent.name, _file1_host, _file2_full_path / _dirent.name, _file2_host, _result);
            if( ret != 0 )
                return false;
            return true;
        });
    }
    return 0;
}

static std::vector<VFSListingItem>
FetchItems(const std::string &_directory_path, const std::vector<std::string> &_filenames, VFSHost &_host)
{
    std::vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}
