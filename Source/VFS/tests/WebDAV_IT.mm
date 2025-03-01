// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../source/NetWebDAV/WebDAVHost.h"
#include "NCE.h"
#include "TestEnv.h"
#include "Tests.h"
#include <VFS/Native.h>
#include <VFS/VFSEasyOps.h>
#include <functional>
#include <memory>
#include <span>
#include <sys/stat.h>

#define PREFIX "WebDAV "

using namespace nc;
using namespace nc::vfs;

// Apache/2.4.41 on Ubuntu 20.04 LTS running in a Docker
static const auto g_Ubuntu2004Host = "127.0.0.1";
static const auto g_Ubuntu2004Username = "r2d2";
static const auto g_Ubuntu2004Password = "Hello";
static const auto g_Ubuntu2004Port = 9080;

static const auto g_YandexDiskUsername = NCE(nc::env::test::webdav_yandexdisk_username);
static const auto g_YandexDiskPassword = NCE(nc::env::test::webdav_yandexdisk_password);

static std::vector<std::byte> MakeNoise(size_t size);
static void VerifyFileContent(VFSHost &_host, const std::filesystem::path &_path, std::span<const std::byte> _content);
static void WriteWholeFile(VFSHost &_host, const std::filesystem::path &_path, std::span<const std::byte> _content);

static std::shared_ptr<WebDAVHost> spawnLocalHost()
{
    return std::make_shared<WebDAVHost>(
        g_Ubuntu2004Host, g_Ubuntu2004Username, g_Ubuntu2004Password, "webdav", false, g_Ubuntu2004Port);
}

static std::shared_ptr<WebDAVHost> spawnYandexDiskHost()
{
    return std::make_shared<WebDAVHost>("webdav.yandex.com", g_YandexDiskUsername, g_YandexDiskPassword, "", true);
}

static std::shared_ptr<WebDAVHost> Spawn(const std::string &_server)
{
    if( _server == "local" )
        return spawnLocalHost();
    if( _server == "yandex.com" )
        return spawnYandexDiskHost();
    return nullptr;
}

#define INSTANTIATE_TEST(Name, Function, Server)                                                                       \
    TEST_CASE(PREFIX Name " - " Server)                                                                                \
    {                                                                                                                  \
        Function(Spawn(Server));                                                                                       \
    }

TEST_CASE(PREFIX "can connect to localhost")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnLocalHost());
    CHECK(host->FetchDirectoryListing("/", 0));
}

TEST_CASE(PREFIX "can connect to yandex.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnYandexDiskHost());
}

TEST_CASE(PREFIX "invalid credentials")
{
    REQUIRE_THROWS_AS(
        new WebDAVHost("localhost", g_Ubuntu2004Username, "SomeRandomGibberish", "webdav", false, g_Ubuntu2004Port),
        ErrorException);
}

/*==================================================================================================
fetching listings
==================================================================================================*/
static void TestFetchDirectoryListing(VFSHostPtr _host)
{
    const auto p1 = "/Test1";
    const auto pp1 = "/Test1/Dir1";
    const auto pp2 = "/Test1/meow.txt";
    const auto ppp1 = "/Test1/Dir1/purr.txt";
    std::ignore = VFSEasyDelete(p1, _host);
    REQUIRE(_host->CreateDirectory(p1, 0));
    REQUIRE(_host->CreateDirectory(pp1, 0));
    const std::string_view content = "Hello, World!";
    WriteWholeFile(*_host, pp2, {reinterpret_cast<const std::byte *>(content.data()), content.size()});
    WriteWholeFile(*_host, ppp1, {reinterpret_cast<const std::byte *>(content.data()), content.size()});

    VFSListingPtr listing;
    const auto has_fn = [&listing](const char *_fn) {
        return std::any_of(std::begin(*listing), std::end(*listing), [_fn](auto &_i) { return _i.Filename() == _fn; });
    };

    REQUIRE(!_host->FetchDirectoryListing("", 0));
    REQUIRE(!_host->FetchDirectoryListing("/DontExist", 0));

    listing = _host->FetchDirectoryListing("/", 0).value();
    REQUIRE(listing->Count() == 1);
    REQUIRE(!has_fn(".."));
    REQUIRE(has_fn("Test1"));

    listing = _host->FetchDirectoryListing("/Test1", 0).value();
    REQUIRE(listing->Count() == 3);
    REQUIRE(has_fn(".."));
    REQUIRE(has_fn("meow.txt"));
    REQUIRE(has_fn("Dir1"));

    listing = _host->FetchDirectoryListing("/Test1/Dir1", 0).value();
    REQUIRE(listing->Count() == 2);
    REQUIRE(has_fn(".."));
    REQUIRE(has_fn("purr.txt"));

    // now let's do some Stat()s
    VFSStat st = _host->Stat("/Test1", 0).value();
    REQUIRE(st.mode_bits.dir);
    REQUIRE(!st.mode_bits.reg);
    st = _host->Stat("/Test1/", 0).value();
    REQUIRE(st.mode_bits.dir);
    REQUIRE(!st.mode_bits.reg);
    st = _host->Stat("/Test1/meow.txt", 0).value();
    REQUIRE(!st.mode_bits.dir);
    REQUIRE(st.mode_bits.reg);
    REQUIRE(st.size == 13);
    st = _host->Stat("/Test1/Dir1/purr.txt", 0).value();
    REQUIRE(!st.mode_bits.dir);
    REQUIRE(st.mode_bits.reg);
    REQUIRE(st.size == 13);
    REQUIRE(!_host->Stat("/SomeGibberish/MoreGibberish/EvenMoregibberish.txt", 0));
}
INSTANTIATE_TEST("directory listing", TestFetchDirectoryListing, "local");
// INSTANTIATE_TEST("directory listing", TestFetchDirectoryListing, "yandex.com"); - might have garbage

/*==================================================================================================
 simple file write
==================================================================================================*/
static void TestSimpleFileWrite(VFSHostPtr _host)
{
    const auto path = "/temp_file";
    if( _host->Exists(path) )
        std::ignore = VFSEasyDelete(path, _host);

    const VFSFilePtr file = _host->CreateFile(path).value();

    const auto open_rc = file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create);
    REQUIRE(open_rc == VFSError::Ok);

    const std::string_view str{"Hello, world!"};
    REQUIRE(file->SetUploadSize(str.size()) == VFSError::Ok);
    REQUIRE(file->WriteFile(str.data(), str.size()));

    REQUIRE(file->Close() == VFSError::Ok);

    const auto open_rc2 = file->Open(VFSFlags::OF_Read);
    REQUIRE(open_rc2 == VFSError::Ok);

    const auto d = file->ReadFile();

    REQUIRE(d);

    REQUIRE(d->size() == str.size());
    REQUIRE(str == std::string_view{reinterpret_cast<const char *>(d->data()), d->size()});

    REQUIRE(file->Close() == VFSError::Ok);

    std::ignore = VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("simple file write", TestSimpleFileWrite, "local");
INSTANTIATE_TEST("simple file write", TestSimpleFileWrite, "yandex.com");

/*==================================================================================================
 various complete writes
==================================================================================================*/
static void TestVariousCompleteWrites(VFSHostPtr _host)
{
    const auto path = "/temp_file";
    if( _host->Exists(path) )
        std::ignore = VFSEasyDelete(path, _host);

    const VFSFilePtr file = _host->CreateFile(path).value();

    const auto open_rc = file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create);
    REQUIRE(open_rc == VFSError::Ok);

    const size_t file_size = 12'345'678; // ~12MB
    const auto noise = MakeNoise(file_size);

    file->SetUploadSize(file_size);

    size_t write_chunk = std::numeric_limits<size_t>::max();
    SECTION("")
    {
        write_chunk = 439;
    }
    SECTION("")
    {
        write_chunk = 1234;
    }
    SECTION("")
    {
        write_chunk = 2000;
    }
    SECTION("")
    {
        write_chunk = 2048;
    }
    SECTION("")
    {
        write_chunk = 5000;
    }
    SECTION("")
    {
        write_chunk = 77777;
    }
    SECTION("")
    {
        write_chunk = file_size / 2;
    }
    SECTION("")
    {
        write_chunk = file_size;
    }
    SECTION("")
    {
        write_chunk = file_size * 2;
    }

    ssize_t left_to_write = file_size;
    const std::byte *read_from = noise.data();
    while( left_to_write > 0 ) {
        const auto write_now = std::min(write_chunk, static_cast<size_t>(left_to_write));
        const auto write_rc = file->Write(read_from, write_now);
        REQUIRE(write_rc >= 0);
        read_from += write_rc;
        left_to_write -= write_rc;
    }

    REQUIRE(file->Close() == VFSError::Ok);

    VerifyFileContent(*_host, path, noise);

    std::ignore = VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("various complete writes", TestVariousCompleteWrites, "local");
// Yandex.disk doesn't like big uploads via WebDAV and imposes huge wait time, which fails at
// timeouts, so skip it.

/*==================================================================================================
 edge case - 1b writes
==================================================================================================*/
static void TestEdgeCase1bWrites(VFSHostPtr _host)
{
    const auto path = "/temp_file";
    if( _host->Exists(path) )
        std::ignore = VFSEasyDelete(path, _host);

    const VFSFilePtr file = _host->CreateFile(path).value();

    const auto open_rc = file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create);
    REQUIRE(open_rc == VFSError::Ok);

    constexpr size_t file_size = 9;
    char data[file_size + 1] = "012345678";
    file->SetUploadSize(file_size);
    for( int i = 0; i != file_size; ++i )
        REQUIRE(file->Write(data + i, 1) == 1);

    REQUIRE(file->Close() == VFSError::Ok);

    VerifyFileContent(*_host, path, {reinterpret_cast<std::byte *>(data), file_size});

    std::ignore = VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("edge case - 1b writes", TestEdgeCase1bWrites, "local");
INSTANTIATE_TEST("edge case - 1b writes", TestEdgeCase1bWrites, "yandex.com");

/*==================================================================================================
 aborts pending uploads
==================================================================================================*/
static void TestAbortsPendingUploads(VFSHostPtr _host)
{
    const auto path = "/temp_file";
    if( _host->Exists(path) )
        std::ignore = VFSEasyDelete(path, _host);

    const VFSFilePtr file = _host->CreateFile(path).value();

    const auto open_rc = file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create);
    REQUIRE(open_rc == VFSError::Ok);

    const size_t file_size = 1000;
    const auto noise = MakeNoise(file_size);
    REQUIRE(file->SetUploadSize(file_size) == VFSError::Ok);

    REQUIRE(file->WriteFile(noise.data(), file_size - 1));

    REQUIRE(file->Close() == VFSError::Ok);

    REQUIRE(_host->Exists(path) == false);
}
INSTANTIATE_TEST("aborts pending uploads", TestAbortsPendingUploads, "local");
INSTANTIATE_TEST("aborts pending uploads", TestAbortsPendingUploads, "yandex.com");

/*==================================================================================================
aborts pending downloads
==================================================================================================*/
static void TestAbortsPendingDownloads(VFSHostPtr _host)
{
    const auto path = "/temp_file";
    if( _host->Exists(path) )
        std::ignore = VFSEasyDelete(path, _host);
    {
        const size_t file_size = 100000; // 100Kb
        const auto noise = MakeNoise(file_size);
        const VFSFilePtr file = _host->CreateFile(path).value();
        REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == VFSError::Ok);
        REQUIRE(file->SetUploadSize(file_size) == VFSError::Ok);
        REQUIRE(file->WriteFile(noise.data(), file_size));
        REQUIRE(file->Close() == VFSError::Ok);
    }
    {
        std::array<std::byte, 1000> buf; // 1Kb
        const VFSFilePtr file = _host->CreateFile(path).value();
        REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
        REQUIRE(file->Read(buf.data(), buf.size()) == buf.size());
        REQUIRE(file->Close() == VFSError::Ok);
    }
    std::ignore = VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("aborts pending downloads", TestAbortsPendingDownloads, "local");
INSTANTIATE_TEST("aborts pending downloads", TestAbortsPendingDownloads, "yandex.com");

/*==================================================================================================
empty file creation
==================================================================================================*/
static void TestEmptyFileCreation(VFSHostPtr _host)
{
    const auto path = "/empty_file";
    if( _host->Exists(path) )
        std::ignore = VFSEasyDelete(path, _host);

    const VFSFilePtr file = _host->CreateFile(path).value();

    const auto open_rc = file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create);
    REQUIRE(open_rc == VFSError::Ok);

    REQUIRE(file->SetUploadSize(0) == VFSError::Ok);

    REQUIRE(file->Close() == VFSError::Ok);

    REQUIRE(_host->Exists(path));

    std::ignore = VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("empty file creation", TestEmptyFileCreation, "local");
INSTANTIATE_TEST("empty file creation", TestEmptyFileCreation, "yandex.com");

/*==================================================================================================
can download empty file :-|
==================================================================================================*/
static void TestEmptyFileDownload(VFSHostPtr _host)
{
    const auto path = "/temp_file";
    if( _host->Exists(path) )
        std::ignore = VFSEasyDelete(path, _host);
    {
        const VFSFilePtr file = _host->CreateFile(path).value();
        REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == VFSError::Ok);
        REQUIRE(file->SetUploadSize(0) == VFSError::Ok);
        REQUIRE(file->Close() == VFSError::Ok);
    }
    {
        const VFSFilePtr file = _host->CreateFile(path).value();
        REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
        REQUIRE(file->Close() == VFSError::Ok);
    }
    std::ignore = VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("can download empty file", TestEmptyFileDownload, "local");
INSTANTIATE_TEST("can download empty file", TestEmptyFileDownload, "yandex.com");

/*==================================================================================================
complex copy
==================================================================================================*/
static void TestComplexCopy(VFSHostPtr _host)
{
    std::ignore = VFSEasyDelete("/Test2", _host);
    const auto copy_rc =
        VFSEasyCopyDirectory("/System/Library/Filesystems/msdos.fs", TestEnv().vfs_native, "/Test2", _host);
    REQUIRE(copy_rc == VFSError::Ok);

    int res = 0;
    const int cmp_rc =
        VFSCompareNodes("/System/Library/Filesystems/msdos.fs", TestEnv().vfs_native, "/Test2", _host, res);

    CHECK(cmp_rc == VFSError::Ok);
    CHECK(res == 0);

    std::ignore = VFSEasyDelete("/Test2", _host);
}
INSTANTIATE_TEST("complex copy", TestComplexCopy, "local");
INSTANTIATE_TEST("complex copy", TestComplexCopy, "yandex.com");

/*==================================================================================================
rename
==================================================================================================*/
static void TestRename(VFSHostPtr _host)
{
    SECTION("simple reg -> reg in the same dir")
    {
        const auto p1 = "/new_empty_file";
        const auto p2 = "/new_empty_file_1";
        std::ignore = VFSEasyDelete(p1, _host);
        std::ignore = VFSEasyDelete(p2, _host);
        REQUIRE(VFSEasyCreateEmptyFile(p1, _host) == VFSError::Ok);
        REQUIRE(_host->Rename(p1, p2, nullptr));
        REQUIRE(_host->Exists(p1) == false);
        REQUIRE(_host->Exists(p2) == true);
        std::ignore = VFSEasyDelete(p2, _host);
    }
    SECTION("simple reg -> reg in other dir")
    {
        const auto p1 = "/new_empty_file";
        const auto p2 = std::filesystem::path("/TestTestDir/new_empty_file_1");
        std::ignore = VFSEasyDelete(p1, _host);
        std::ignore = VFSEasyDelete(p2.parent_path().c_str(), _host);
        REQUIRE(VFSEasyCreateEmptyFile(p1, _host) == VFSError::Ok);
        REQUIRE(_host->CreateDirectory(p2.parent_path().c_str(), 0));
        REQUIRE(_host->Rename(p1, p2.c_str()));
        REQUIRE(_host->Exists(p1) == false);
        REQUIRE(_host->Exists(p2.c_str()) == true);
        std::ignore = VFSEasyDelete(p2.parent_path().c_str(), _host);
    }
    SECTION("simple dir -> dir in the same dir")
    {
        const auto p1 = "/TestTestDir1";
        const auto p2 = "/TestTestDir2";
        std::ignore = VFSEasyDelete(p1, _host);
        std::ignore = VFSEasyDelete(p2, _host);
        REQUIRE(_host->CreateDirectory(p1, 0));
        REQUIRE(_host->Rename(p1, p2));
        REQUIRE(_host->Exists(p1) == false);
        REQUIRE(_host->Exists(p2) == true);
        REQUIRE(_host->IsDirectory(p2, 0) == true);
        std::ignore = VFSEasyDelete(p2, _host);
    }
    SECTION("simple dir -> dir in other dir")
    {
        const auto p1 = "/TestTestDir1";
        const auto p2 = "/TestTestDir2";
        const auto p3 = "/TestTestDir2/NestedDir";
        std::ignore = VFSEasyDelete(p1, _host);
        std::ignore = VFSEasyDelete(p2, _host);
        REQUIRE(_host->CreateDirectory(p1, 0));
        REQUIRE(_host->CreateDirectory(p2, 0));
        REQUIRE(_host->Rename(p1, p3));
        REQUIRE(_host->Exists(p1) == false);
        REQUIRE(_host->Exists(p3) == true);
        REQUIRE(_host->IsDirectory(p3, 0) == true);
        std::ignore = VFSEasyDelete(p2, _host);
    }
    SECTION("dir with items -> dir in the same dir")
    {
        const auto p1 = "/TestTestDir1";
        const auto pp1 = "/TestTestDir1/meow.txt";
        const auto p2 = "/TestTestDir2";
        const auto pp2 = "/TestTestDir2/meow.txt";
        std::ignore = VFSEasyDelete(p1, _host);
        std::ignore = VFSEasyDelete(p2, _host);
        REQUIRE(_host->CreateDirectory(p1, 0));
        REQUIRE(VFSEasyCreateEmptyFile(pp1, _host) == VFSError::Ok);
        REQUIRE(_host->Rename(p1, p2));
        REQUIRE(_host->Exists(p1) == false);
        REQUIRE(_host->Exists(pp1) == false);
        REQUIRE(_host->Exists(p2) == true);
        REQUIRE(_host->Exists(pp2) == true);
        REQUIRE(_host->IsDirectory(p2, 0) == true);
        std::ignore = VFSEasyDelete(p2, _host);
    }
}
INSTANTIATE_TEST("rename", TestRename, "local");
INSTANTIATE_TEST("rename", TestRename, "yandex.com");

/*==================================================================================================
statfs
==================================================================================================*/
static void TestStatFS(VFSHostPtr _host)
{
    const VFSStatFS st = _host->StatFS("/").value();
    CHECK(st.total_bytes > 1'000'000'000L);
}
// INSTANTIATE_TEST("statfs", TestStatFS, "local"); // apache2 doesn't provide stafs (??)
INSTANTIATE_TEST("statfs", TestStatFS, "yandex.com");

/*==================================================================================================
simple download
==================================================================================================*/
static void TestSimpleDownload(VFSHostPtr _host)
{
    const auto config = _host->Configuration();
    const size_t file_size = 147'839;
    const auto noise = MakeNoise(file_size);

    SECTION("File at root")
    {
        const auto path = "/SomeTestFile.extensiondoesntmatter";
        std::ignore = VFSEasyDelete(path, _host);
        {
            const VFSFilePtr file = _host->CreateFile(path).value();
            REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == VFSError::Ok);
            REQUIRE(file->SetUploadSize(file_size) == VFSError::Ok);
            REQUIRE(file->WriteFile(noise.data(), file_size));
            REQUIRE(file->Close() == VFSError::Ok);
        }
        SECTION("reusing same host")
        {
        }
        SECTION("using a fresh host")
        {
            _host = std::make_shared<WebDAVHost>(config);
        }
        {
            const VFSFilePtr file = _host->CreateFile(path).value();
            REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
            const auto data = file->ReadFile();
            REQUIRE(file->Close() == VFSError::Ok);
            REQUIRE(data);
            REQUIRE(data->size() == file_size);
            REQUIRE(std::memcmp(data->data(), noise.data(), file_size) == 0);
        }
        std::ignore = VFSEasyDelete(path, _host);
    }
    SECTION("File at one dir below root")
    {
        const auto dir = "/TestDirWithNonsenseName";
        const auto path = "/TestDirWithNonsenseName/SomeTestFile.extensiondoesntmatter";
        std::ignore = VFSEasyDelete(dir, _host);
        REQUIRE(_host->CreateDirectory(dir, 0));
        {
            const VFSFilePtr file = _host->CreateFile(path).value();
            REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == VFSError::Ok);
            REQUIRE(file->SetUploadSize(file_size) == VFSError::Ok);
            REQUIRE(file->WriteFile(noise.data(), file_size));
            REQUIRE(file->Close() == VFSError::Ok);
        }
        SECTION("reusing same host")
        {
        }
        SECTION("using a fresh host")
        {
            _host = std::make_shared<WebDAVHost>(config);
        }
        {
            const VFSFilePtr file = _host->CreateFile(path).value();
            REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
            const auto data = file->ReadFile();
            REQUIRE(file->Close() == VFSError::Ok);
            REQUIRE(data);
            REQUIRE(data->size() == file_size);
            REQUIRE(std::memcmp(data->data(), noise.data(), file_size) == 0);
        }
        std::ignore = VFSEasyDelete(dir, _host);
    }
    SECTION("File at two dirs below root")
    {
        const auto dir1 = "/TestDirWithNonsenseName";
        const auto dir2 = "/TestDirWithNonsenseName/MoreStuff";
        const auto path = "/TestDirWithNonsenseName/MoreStuff/SomeTestFile.extensiondoesntmatter";
        std::ignore = VFSEasyDelete(dir1, _host);
        REQUIRE(_host->CreateDirectory(dir1, 0));
        REQUIRE(_host->CreateDirectory(dir2, 0));
        {
            const VFSFilePtr file = _host->CreateFile(path).value();
            REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == VFSError::Ok);
            REQUIRE(file->SetUploadSize(file_size) == VFSError::Ok);
            REQUIRE(file->WriteFile(noise.data(), file_size));
            REQUIRE(file->Close() == VFSError::Ok);
        }
        SECTION("reusing same host")
        {
        }
        SECTION("using a fresh host")
        {
            _host = std::make_shared<WebDAVHost>(config);
        }
        {
            const VFSFilePtr file = _host->CreateFile(path).value();
            REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
            const auto data = file->ReadFile();
            REQUIRE(file->Close() == VFSError::Ok);
            REQUIRE(data);
            REQUIRE(data->size() == file_size);
            REQUIRE(std::memcmp(data->data(), noise.data(), file_size) == 0);
        }
        std::ignore = VFSEasyDelete(dir1, _host);
    }
}
INSTANTIATE_TEST("simple download", TestSimpleDownload, "local");
INSTANTIATE_TEST("simple download", TestSimpleDownload, "yandex.com");

/*==================================================================================================
write flags semantics
==================================================================================================*/
static void TestWriteFlagsSemantics(VFSHostPtr _host)
{
    const auto config = _host->Configuration();
    const auto path = "/SomeTestFile.extensiondoesntmatter";
    std::ignore = VFSEasyDelete(path, _host);
    SECTION("Specifying both OF_Read and OF_Write is not supported")
    {
        const VFSFilePtr file = _host->CreateFile(path).value();
        REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Read) == VFSError::FromErrno(EPERM));
    }
    SECTION("OF_NoExist forces to fail when a file already exist")
    {
        {
            const VFSFilePtr file = _host->CreateFile(path).value();
            REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == VFSError::Ok);
            REQUIRE(file->SetUploadSize(0) == VFSError::Ok);
            REQUIRE(file->Close() == VFSError::Ok);
        }
        {
            const VFSFilePtr file = _host->CreateFile(path).value();
            REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_NoExist) == VFSError::FromErrno(EEXIST));
        }
    }
    SECTION("Open a non-existing file for writing without OF_Create fails")
    {
        const VFSFilePtr file = _host->CreateFile(path).value();
        REQUIRE(file->Open(VFSFlags::OF_Write) == VFSError::FromErrno(ENOENT));
    }
    SECTION("Opening an existing directory for writing fails")
    {
        REQUIRE(_host->CreateDirectory(path, 0));
        const VFSFilePtr file = _host->CreateFile(path).value();
        REQUIRE(file->Open(VFSFlags::OF_Write) == VFSError::FromErrno(EISDIR));
    }
    SECTION("Opening an existing file for writing overwrites it")
    {
        const std::string old_data = "123456";
        const std::string new_data = "0987654321";
        {
            const VFSFilePtr file = _host->CreateFile(path).value();
            REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == VFSError::Ok);
            REQUIRE(file->SetUploadSize(old_data.size()) == VFSError::Ok);
            REQUIRE(file->WriteFile(old_data.data(), old_data.size()));
            REQUIRE(file->Close() == VFSError::Ok);
        }
        {
            const VFSFilePtr file = _host->CreateFile(path).value();
            REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == VFSError::Ok);
            REQUIRE(file->SetUploadSize(new_data.size()) == VFSError::Ok);
            REQUIRE(file->WriteFile(new_data.data(), new_data.size()));
            REQUIRE(file->Close() == VFSError::Ok);
        }
        {
            const VFSFilePtr file = _host->CreateFile(path).value();
            REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
            const auto data = file->ReadFile();
            REQUIRE(file->Close() == VFSError::Ok);
            REQUIRE(data);
            REQUIRE(data->size() == new_data.size());
            REQUIRE(std::memcmp(data->data(), new_data.data(), new_data.size()) == 0);
        }
    }
    std::ignore = VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("write flags semantics", TestWriteFlagsSemantics, "local");
INSTANTIATE_TEST("write flags semantics", TestWriteFlagsSemantics, "yandex.com");

//==================================================================================================

static std::vector<std::byte> MakeNoise(size_t size)
{
    std::vector<std::byte> noise(size);
    std::srand(static_cast<unsigned>(time(nullptr)));
    for( size_t i = 0; i < size; ++i )
        noise[i] = static_cast<std::byte>(std::rand() % 256); // yes, I know that rand() is harmful!
    return noise;
}

static void VerifyFileContent(VFSHost &_host, const std::filesystem::path &_path, std::span<const std::byte> _content)
{
    const VFSFilePtr file = _host.CreateFile(_path.c_str()).value();

    const auto open_rc = file->Open(VFSFlags::OF_Read);
    REQUIRE(open_rc == VFSError::Ok);
    const auto d = file->ReadFile();
    REQUIRE(d);
    REQUIRE(d->size() == _content.size());
    REQUIRE(memcmp(d->data(), _content.data(), _content.size()) == 0);
    REQUIRE(file->Close() == VFSError::Ok);
}

static void WriteWholeFile(VFSHost &_host, const std::filesystem::path &_path, std::span<const std::byte> _content)
{
    const VFSFilePtr file = _host.CreateFile(_path.c_str()).value();

    const auto open_rc = file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create);
    REQUIRE(open_rc == VFSError::Ok);

    REQUIRE(file->SetUploadSize(_content.size()) == VFSError::Ok);
    REQUIRE(file->WriteFile(_content.data(), _content.size()));

    REQUIRE(file->Close() == VFSError::Ok);
}
