// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <filesystem>
#include <sys/stat.h>
#include <sys/xattr.h>
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

static std::expected<int, Error> VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                                                   const VFSHostPtr &_file1_host,
                                                   const std::filesystem::path &_file2_full_path,
                                                   const VFSHostPtr &_file2_host);

static std::vector<VFSListingItem>
FetchItems(const std::string &_directory_path, const std::vector<std::string> &_filenames, VFSHost &_host);
static bool touch(const std::filesystem::path &_path);

TEST_CASE(PREFIX "Empty archive building")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    Compression operation{std::vector<VFSListingItem>{}, tmp_dir.directory, native_host};
    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));
    CHECK(arc_host->StatTotalFiles() == 0);
}

TEST_CASE(PREFIX "Compressing Mac kernel")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;

    Compression operation{
        FetchItems("/System/Library/Kernels/", {"kernel"}, *native_host), tmp_dir.directory, native_host};

    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    CHECK(operation.Statistics().ElapsedTime() > 1ms);
    CHECK(operation.Statistics().ElapsedTime() < 5s);
    REQUIRE(native_host->Exists(operation.ArchivePath()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));
    CHECK(arc_host->StatTotalFiles() == 1);
    CHECK(VFSEasyCompareFiles("/System/Library/Kernels/kernel", native_host, "/kernel", arc_host) == 0);
}

TEST_CASE(PREFIX "Compressing Bin utilities")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;

    const std::vector<std::string> filenames = {
        "[",        "bash",  "cat", "chmod",     "cp",   "csh",  "date", "dd",    "df",     "echo",      "ed", "expr",
        "hostname", "kill",  "ksh", "launchctl", "link", "ln",   "ls",   "mkdir", "mv",     "pax",       "ps", "pwd",
        "rm",       "rmdir", "sh",  "sleep",     "stty", "sync", "tcsh", "test",  "unlink", "wait4path", "zsh"};

    Compression operation{FetchItems("/bin/", filenames, *native_host), tmp_dir.directory, native_host};

    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));
    CHECK(arc_host->StatTotalFiles() == filenames.size());

    for( auto &fn : filenames ) {
        CHECK(VFSEasyCompareFiles(("/bin/"s + fn).c_str(), native_host, ("/"s + fn).c_str(), arc_host) == 0);
    }
}

TEST_CASE(PREFIX "Compressing Bin directory")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;

    Compression operation{FetchItems("/", {"bin"}, *native_host), tmp_dir.directory, native_host};

    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));

    CHECK(VFSCompareEntries("/bin/", native_host, "/bin/", arc_host).value() == 0);
}

TEST_CASE(PREFIX "Compressing Chess.app")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;

    Compression operation{
        FetchItems("/System/Applications/", {"Chess.app"}, *native_host), tmp_dir.directory, native_host};

    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));

    CHECK(VFSCompareEntries("/System/Applications/Chess.app", native_host, "/Chess.app", arc_host).value() == 0);
}

TEST_CASE(PREFIX "Compressing kernel into encrypted archive")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    const auto passwd = "This is a very secret password";

    Compression operation{
        FetchItems("/System/Library/Kernels/", {"kernel"}, *native_host), tmp_dir.directory, native_host, passwd};

    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath()));

    try {
        std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host);
        REQUIRE(false);
    } catch( const ErrorException &e ) {
        REQUIRE(e.error() == Error{VFSError::ErrorDomain, VFSError::ArclibPasswordRequired});
    }

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host =
                        std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host, passwd));
    CHECK(VFSEasyCompareFiles("/System/Library/Kernels/kernel", native_host, "/kernel", arc_host) == 0);
}

TEST_CASE(PREFIX "Compressing /bin into encrypted archive")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    const auto passwd = "This is a very secret password";

    Compression operation{FetchItems("/", {"bin"}, *native_host), tmp_dir.directory, native_host, passwd};

    operation.Start();
    operation.Wait();

    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host =
                        std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host, passwd));
    CHECK(VFSCompareEntries("/bin/", native_host, "/bin/", arc_host).value() == 0);
}

TEST_CASE(PREFIX "Compressing an item with xattrs")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;
    auto str_to_bytes = [](std::string_view _str) -> std::vector<std::byte> {
        return {reinterpret_cast<const std::byte *>(_str.data()),
                reinterpret_cast<const std::byte *>(_str.data()) + _str.length()};
    };

    struct EA {
        std::string name;
        std::vector<std::byte> bytes;
    };
    struct TC {
        std::vector<EA> eas;
    } const tcs[] = {
        {{EA{.name = "hello", .bytes = str_to_bytes("hello")}}},
        {{EA{.name = "hello", .bytes = str_to_bytes("hello")}, EA{.name = "hi", .bytes = str_to_bytes("privet")}}},
        {{EA{.name = "hello", .bytes = str_to_bytes("hello")},
          EA{.name = "hi", .bytes = str_to_bytes("privet")},
          EA{.name = "another", .bytes = str_to_bytes("hola")}}},
        {{EA{.name = "empty", .bytes = str_to_bytes("")}}},
        {{EA{.name = std::string(XATTR_MAXNAMELEN, 'X'), .bytes = str_to_bytes("an xattr with a very long name")}}},
        {{EA{.name = "an xattr with a 128KB content",
             .bytes = std::vector<std::byte>(128ull * 1024ull, std::byte{0xFE})}}},
    };

    const std::filesystem::path filepath = tmp_dir.directory / "a";
    for( const TC &tc : tcs ) {
        // create the file to compress
        REQUIRE(touch(filepath));

        // write the extended attributes into the file
        for( const EA &ea : tc.eas ) {
            setxattr(filepath.c_str(), ea.name.c_str(), ea.bytes.data(), ea.bytes.size(), 0, 0);
        }

        // compress
        Compression operation{
            FetchItems(tmp_dir.directory, {filepath.filename()}, *native_host), tmp_dir.directory, native_host};
        operation.Start();
        operation.Wait();
        REQUIRE(operation.State() == OperationState::Completed);
        REQUIRE(native_host->Exists(operation.ArchivePath()));

        // open the archive
        std::shared_ptr<vfs::ArchiveHost> arc_host;
        REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));

        // open the compressed file in the archive
        const std::shared_ptr<VFSFile> file = arc_host->CreateFile("/" + filepath.filename().native()).value();
        REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);

        // check the number of compressed extended attributes is the same as in the original file
        REQUIRE(file->XAttrCount() == tc.eas.size());

        // check that each extracted extended attribute is equal to the original
        for( const EA &ea : tc.eas ) {
            REQUIRE(static_cast<size_t>(file->XAttrGet(ea.name.c_str(), nullptr, 0)) == ea.bytes.size());
            std::vector<std::byte> bytes(ea.bytes.size());
            REQUIRE(static_cast<size_t>(file->XAttrGet(ea.name.c_str(), bytes.data(), bytes.size())) ==
                    ea.bytes.size());
            REQUIRE(bytes == ea.bytes);
        }

        // cleanup the file that was compressed
        REQUIRE(std::filesystem::remove(filepath));
    }
}

TEST_CASE(PREFIX "Compressing multiple items with xattrs")
{
    const TempTestDir tmp_dir;
    const auto native_host = TestEnv().vfs_native;

    // arrange the file structure to compress
    const std::filesystem::path file0 = "file0.txt";
    const std::filesystem::path dir1 = "dir1";
    const std::filesystem::path file1 = "dir1/file1.txt";
    const std::filesystem::path dir2 = "dir2";
    const std::filesystem::path file2 = "dir2/file2.txt";
    REQUIRE(std::filesystem::create_directory(tmp_dir.directory / dir1));
    REQUIRE(std::filesystem::create_directory(tmp_dir.directory / dir2));
    REQUIRE(touch(tmp_dir.directory / file0));
    REQUIRE(touch(tmp_dir.directory / file1));
    REQUIRE(touch(tmp_dir.directory / file2));
    for( const auto &p : {file0, file1, file2, dir1, dir2} ) {
        // write a single xattr to each file - the filename as a string
        const std::string val = p.filename().native();
        setxattr((tmp_dir.directory / p).c_str(), "attr", val.c_str(), val.length(), 0, 0);
    }

    // compress
    Compression operation{
        FetchItems(tmp_dir.directory, {file0.filename(), dir1.filename(), dir2.filename()}, *native_host),
        tmp_dir.directory,
        native_host};
    operation.Start();
    operation.Wait();
    REQUIRE(operation.State() == OperationState::Completed);
    REQUIRE(native_host->Exists(operation.ArchivePath()));

    // open the archive
    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));

    for( const auto &p : {file0, file1, file2, dir1, dir2} ) {
        // open the compressed file in the archive
        const std::filesystem::path path = std::filesystem::path("/") / p;
        const std::shared_ptr<VFSFile> file = arc_host->CreateFile(path.native()).value();
        REQUIRE(file->Open(p.native().ends_with(".txt")
                               ? VFSFlags::OF_Read
                               : (VFSFlags::OF_Read | VFSFlags::OF_Directory)) == VFSError::Ok);
        // read the xattr and check its value
        REQUIRE(file->XAttrCount() == 1);
        REQUIRE(file->XAttrGet("attr", nullptr, 0) > 0);
        std::string val(file->XAttrGet("attr", nullptr, 0), '\0');
        REQUIRE(file->XAttrGet("attr", val.data(), val.size()) > 0);
        REQUIRE(val == p.filename().native());
    }
}

TEST_CASE(PREFIX "Long compression stats (compressing Music.app)")
{
    const TempTestDir tmp_dir;
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
    REQUIRE(native_host->Exists(operation.ArchivePath()));

    std::shared_ptr<vfs::ArchiveHost> arc_host;
    REQUIRE_NOTHROW(arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), native_host));
    CHECK(VFSCompareEntries("/System/Applications/Music.app", native_host, "/Music.app", arc_host).value() == 0);
}

TEST_CASE(PREFIX "Item reporting")
{
    const TempTestDir tmp_dir;
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

static std::expected<int, Error> VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                                                   const VFSHostPtr &_file1_host,
                                                   const std::filesystem::path &_file2_full_path,
                                                   const VFSHostPtr &_file2_host)
{
    // not comparing flags, perm, times, xattrs, acls etc now

    const std::expected<VFSStat, Error> st1 = _file1_host->Stat(_file1_full_path.c_str(), VFSFlags::F_NoFollow);
    if( !st1 )
        return std::unexpected(st1.error());

    const std::expected<VFSStat, Error> st2 = _file2_host->Stat(_file2_full_path.c_str(), VFSFlags::F_NoFollow);
    if( !st2 )
        return std::unexpected(st2.error());

    if( (st1->mode & S_IFMT) != (st2->mode & S_IFMT) ) {
        return -1;
    }

    if( S_ISREG(st1->mode) ) {
        if( int64_t(st1->size) - int64_t(st2->size) != 0 )
            return int(int64_t(st1->size) - int64_t(st2->size));
    }
    else if( S_ISLNK(st1->mode) ) {
        const std::expected<std::string, Error> link1 = _file1_host->ReadSymlink(_file1_full_path.c_str());
        if( !link1 )
            return std::unexpected(link1.error());

        const std::expected<std::string, Error> link2 = _file2_host->ReadSymlink(_file2_full_path.c_str());
        if( !link2 )
            return std::unexpected(link2.error());

        if( strcmp(link1->c_str(), link2->c_str()) != 0 )
            return strcmp(link1->c_str(), link2->c_str());
    }
    else if( S_ISDIR(st1->mode) ) {
        std::expected<int, Error> result = 0;
        const std::expected<void, Error> rc =
            _file1_host->IterateDirectoryListing(_file1_full_path.c_str(), [&](const VFSDirEnt &_dirent) {
                result = VFSCompareEntries(
                    _file1_full_path / _dirent.name, _file1_host, _file2_full_path / _dirent.name, _file2_host);
                return result.has_value() && result.value() == 0;
            });
        if( !rc ) {
            return std::unexpected(rc.error());
        }
        return result;
    }
    return 0;
}

static std::vector<VFSListingItem>
FetchItems(const std::string &_directory_path, const std::vector<std::string> &_filenames, VFSHost &_host)
{
    return _host.FetchFlexibleListingItems(_directory_path, _filenames, 0).value_or(std::vector<VFSListingItem>{});
}

static bool touch(const std::filesystem::path &_path)
{
    return close(open(_path.c_str(), O_CREAT | O_RDWR, S_IRWXU)) == 0;
}
