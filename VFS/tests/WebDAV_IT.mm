// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include "../source/NetWebDAV/WebDAVHost.h"
#include <VFS/VFSEasyOps.h>
#include <VFS/Native.h>
#include "NCE.h"
#include <sys/stat.h>
#include <span>
#include <functional>

#define PREFIX "WebDAV "

using namespace nc::vfs;

static const auto g_NASHost = NCE(nc::env::test::webdav_nas_host);
static const auto g_NASUsername = NCE(nc::env::test::webdav_nas_username);
static const auto g_NASPassword = NCE(nc::env::test::webdav_nas_password);
static const auto g_BoxComUsername = NCE(nc::env::test::webdav_boxcom_username);
static const auto g_BoxComPassword = NCE(nc::env::test::webdav_boxcom_password);
static const auto g_YandexDiskUsername = NCE(nc::env::test::webdav_yandexdisk_username);
static const auto g_YandexDiskPassword = NCE(nc::env::test::webdav_yandexdisk_password);

static std::vector<std::byte> MakeNoise(size_t size);
static void
VerifyFileContent(VFSHost &_host, std::filesystem::path _path, std::span<const std::byte> _content);

static std::shared_ptr<WebDAVHost> spawnNASHost()
{
    return std::shared_ptr<WebDAVHost>(
        new WebDAVHost(g_NASHost, g_NASUsername, g_NASPassword, "Public", false, 5000));
}

static std::shared_ptr<WebDAVHost> spawnBoxComHost()
{
    return std::shared_ptr<WebDAVHost>(
        new WebDAVHost("dav.box.com", g_BoxComUsername, g_BoxComPassword, "dav", true));
}

static std::shared_ptr<WebDAVHost> spawnYandexDiskHost()
{
    return std::shared_ptr<WebDAVHost>(
        new WebDAVHost("webdav.yandex.com", g_YandexDiskUsername, g_YandexDiskPassword, "", true));
}

[[clang::no_destroy]] static std::array<std::function<std::shared_ptr<WebDAVHost>()>, 1>
    g_AllFactories = {spawnYandexDiskHost};

[[clang::no_destroy]] static std::array<std::function<std::shared_ptr<WebDAVHost>()>, 2>
    g_AllFactoriesButYandex = {spawnBoxComHost, spawnNASHost};

static std::shared_ptr<WebDAVHost> Spawn(const std::string &_server)
{
    if( _server == "nas" )
        return spawnNASHost();
    if( _server == "box.com" )
        return spawnBoxComHost();
    if( _server == "yandex.com" )
        return spawnYandexDiskHost();
    return nullptr;
}

#define INSTANTIATE_TEST(Name, Function, Server)                                                   \
    TEST_CASE(PREFIX Name " - " Server) { Function(Spawn(Server)); }

TEST_CASE(PREFIX "can connect to local NAS")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnNASHost());

    VFSListingPtr listing;
    int rc = host->FetchDirectoryListing("/", listing, 0, nullptr);
    CHECK(rc == VFSError::Ok);
}

TEST_CASE(PREFIX "can connect to box.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnBoxComHost());
}

TEST_CASE(PREFIX "can fetch box.com listing")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnBoxComHost());

    VFSListingPtr listing;

    int rc = host->FetchDirectoryListing("/", listing, 0, nullptr);
    REQUIRE(rc == VFSError::Ok);

    const auto has_fn = [listing](const char *_fn) {
        return std::any_of(std::begin(*listing), std::end(*listing), [_fn](auto &_i) {
            return _i.Filename() == _fn;
        });
    };

    REQUIRE(!has_fn(".."));
    REQUIRE(has_fn("Test1"));
}

TEST_CASE(PREFIX "can fetch box.com subfolder listing")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnBoxComHost());

    VFSListingPtr listing;

    int rc = host->FetchDirectoryListing("/Test1", listing, 0, nullptr);
    REQUIRE(rc == VFSError::Ok);

    const auto has_fn = [listing](const char *_fn) {
        return std::any_of(std::begin(*listing), std::end(*listing), [_fn](auto &_i) {
            return _i.Filename() == _fn;
        });
    };

    REQUIRE(has_fn(".."));
    REQUIRE(has_fn("README.md"));
    REQUIRE(has_fn("scorpions-lifes_like_a_river.gpx"));
}

TEST_CASE(PREFIX "can fetch multiple listings on box.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnBoxComHost());
    VFSListingPtr listing;

    int rc1 = host->FetchDirectoryListing("/Test1", listing, 0, nullptr);
    REQUIRE(rc1 == VFSError::Ok);
    int rc2 = host->FetchDirectoryListing("/", listing, 0, nullptr);
    REQUIRE(rc2 == VFSError::Ok);
    int rc3 = host->FetchDirectoryListing("/Test1", listing, 0, nullptr);
    REQUIRE(rc3 == VFSError::Ok);
}

TEST_CASE(PREFIX "consecutive stats on box.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnBoxComHost());

    VFSStat st;
    int rc = host->Stat("/Test1/scorpions-lifes_like_a_river.gpx", st, 0, nullptr);
    REQUIRE(rc == VFSError::Ok);
    REQUIRE(st.size == 65039);
    REQUIRE(S_ISREG(st.mode));

    rc = host->Stat("/Test1/README.md", st, 0, nullptr);
    REQUIRE(rc == VFSError::Ok);
    REQUIRE(st.size == 1450);
    REQUIRE(S_ISREG(st.mode));

    rc = host->Stat("/Test1/", st, 0, nullptr);
    REQUIRE(rc == VFSError::Ok);
    REQUIRE(S_ISDIR(st.mode));

    rc = host->Stat("/", st, 0, nullptr);
    REQUIRE(rc == VFSError::Ok);
    REQUIRE(S_ISDIR(st.mode));

    rc = host->Stat("", st, 0, nullptr);
    REQUIRE(rc != VFSError::Ok);

    rc = host->Stat("/SomeGibberish/MoreGibberish/EvenMoregibberish.txt", st, 0, nullptr);
    REQUIRE(rc != VFSError::Ok);
}

TEST_CASE(PREFIX "create directory on box.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnBoxComHost());

    const auto p1 = "/Test2/";
    VFSEasyDelete(p1, host);

    REQUIRE(host->CreateDirectory(p1, 0, nullptr) == VFSError::Ok);
    REQUIRE(host->Exists(p1));
    REQUIRE(host->IsDirectory(p1, 0));

    const auto p2 = "/Test2/SubDir1";
    REQUIRE(host->CreateDirectory(p2, 0, nullptr) == VFSError::Ok);
    REQUIRE(host->Exists(p2));
    REQUIRE(host->IsDirectory(p2, 0));

    const auto p3 = "/Test2/SubDir2";
    REQUIRE(host->CreateDirectory(p3, 0, nullptr) == VFSError::Ok);
    REQUIRE(host->Exists(p3));
    REQUIRE(host->IsDirectory(p3, 0));

    VFSEasyDelete(p1, host);
}

TEST_CASE(PREFIX "file read on box.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnBoxComHost());

    VFSFilePtr file;
    const auto path = "/Test1/scorpions-lifes_like_a_river.gpx";
    const auto filecr_rc = host->CreateFile(path, file, nullptr);
    REQUIRE(filecr_rc == VFSError::Ok);

    const auto open_rc = file->Open(VFSFlags::OF_Read);
    REQUIRE(open_rc == VFSError::Ok);

    auto data = file->ReadFile();
    REQUIRE(data);
    REQUIRE(data->size() == 65039);
    REQUIRE(data->at(65037) == 4);
    REQUIRE(data->at(65038) == 0);
}

/*==================================================================================================
 simple file write
==================================================================================================*/
static void TestSimpleFileWrite(VFSHostPtr _host)
{
    const auto path = "/temp_file";
    if( _host->Exists(path) )
        VFSEasyDelete(path, _host);

    VFSFilePtr file;
    const auto filecr_rc = _host->CreateFile(path, file, nullptr);
    REQUIRE(filecr_rc == VFSError::Ok);

    const auto open_rc = file->Open(VFSFlags::OF_Write);
    REQUIRE(open_rc == VFSError::Ok);

    std::string_view str{"Hello, world!"};
    REQUIRE(file->SetUploadSize(str.size()) == VFSError::Ok);
    const auto write_rc = file->WriteFile(str.data(), str.size());
    REQUIRE(write_rc == VFSError::Ok);

    REQUIRE(file->Close() == VFSError::Ok);

    const auto open_rc2 = file->Open(VFSFlags::OF_Read);
    REQUIRE(open_rc2 == VFSError::Ok);

    const auto d = file->ReadFile();

    REQUIRE(d);

    REQUIRE(d->size() == str.size());
    REQUIRE(str == std::string_view{(const char *)d->data(), d->size()});

    REQUIRE(file->Close() == VFSError::Ok);

    VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("simple file write", TestSimpleFileWrite, "nas");
INSTANTIATE_TEST("simple file write", TestSimpleFileWrite, "box.com");
INSTANTIATE_TEST("simple file write", TestSimpleFileWrite, "yandex.com");

/*==================================================================================================
 various complete writes
==================================================================================================*/
static void TestVariousCompleteWrites(VFSHostPtr _host)
{
    const auto path = "/temp_file";
    if( _host->Exists(path) )
        VFSEasyDelete(path, _host);

    VFSFilePtr file;
    const auto filecr_rc = _host->CreateFile(path, file, nullptr);
    REQUIRE(filecr_rc == VFSError::Ok);

    const auto open_rc = file->Open(VFSFlags::OF_Write);
    REQUIRE(open_rc == VFSError::Ok);

    const size_t file_size = 12'345'678; // ~12MB
    const auto noise = MakeNoise(file_size);

    file->SetUploadSize(file_size);

    size_t write_chunk = std::numeric_limits<size_t>::max();
    SECTION("") { write_chunk = 439; }
    SECTION("") { write_chunk = 1234; }
    SECTION("") { write_chunk = 2000; }
    SECTION("") { write_chunk = 2048; }
    SECTION("") { write_chunk = 5000; }
    SECTION("") { write_chunk = 77777; }
    SECTION("") { write_chunk = file_size / 2; }
    SECTION("") { write_chunk = file_size; }
    SECTION("") { write_chunk = file_size * 2; }

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

    VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("various complete writes", TestVariousCompleteWrites, "nas");
INSTANTIATE_TEST("various complete writes", TestVariousCompleteWrites, "box.com");
// Yandex.disk doesn't like big uploads via WebDAV and imposes huge wait time, which fails at
// timeouts, so skip it.

/*==================================================================================================
 edge case - 1b writes
==================================================================================================*/
static void TestEdgeCase1bWrites(VFSHostPtr _host)
{
    const auto path = "/temp_file";
    if( _host->Exists(path) )
        VFSEasyDelete(path, _host);

    VFSFilePtr file;
    const auto filecr_rc = _host->CreateFile(path, file, nullptr);
    REQUIRE(filecr_rc == VFSError::Ok);

    const auto open_rc = file->Open(VFSFlags::OF_Write);
    REQUIRE(open_rc == VFSError::Ok);

    constexpr size_t file_size = 9;
    char data[file_size + 1] = "012345678";
    file->SetUploadSize(file_size);
    for( int i = 0; i != file_size; ++i )
        REQUIRE(file->Write(data + i, 1) == 1);

    REQUIRE(file->Close() == VFSError::Ok);

    VerifyFileContent(*_host, path, {reinterpret_cast<std::byte *>(data), file_size});

    VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("edge case - 1b writes", TestEdgeCase1bWrites, "nas");
INSTANTIATE_TEST("edge case - 1b writes", TestEdgeCase1bWrites, "box.com");
INSTANTIATE_TEST("edge case - 1b writes", TestEdgeCase1bWrites, "yandex.com");

/*==================================================================================================
 aborts pending uploads
==================================================================================================*/
static void TestAbortsPendingUploads(VFSHostPtr _host)
{
    const auto path = "/temp_file";
    if( _host->Exists(path) )
        VFSEasyDelete(path, _host);

    VFSFilePtr file;
    const auto filecr_rc = _host->CreateFile(path, file, nullptr);
    REQUIRE(filecr_rc == VFSError::Ok);

    const auto open_rc = file->Open(VFSFlags::OF_Write);
    REQUIRE(open_rc == VFSError::Ok);

    const size_t file_size = 1000;
    const auto noise = MakeNoise(file_size);
    REQUIRE(file->SetUploadSize(file_size) == VFSError::Ok);

    REQUIRE(file->WriteFile(noise.data(), file_size - 1) == VFSError::Ok);

    REQUIRE(file->Close() == VFSError::Ok);

    REQUIRE(_host->Exists(path) == false);
}
INSTANTIATE_TEST("aborts pending uploads", TestAbortsPendingUploads, "nas");
INSTANTIATE_TEST("aborts pending uploads", TestAbortsPendingUploads, "box.com");
INSTANTIATE_TEST("aborts pending uploads", TestAbortsPendingUploads, "yandex.com");

/*==================================================================================================
aborts pending downloads
==================================================================================================*/
static void TestAbortsPendingDownloads(VFSHostPtr _host)
{
    const auto path = "/temp_file";
    if( _host->Exists(path) )
        VFSEasyDelete(path, _host);
    {
        const size_t file_size = 100000; // 100Kb
        const auto noise = MakeNoise(file_size);
        VFSFilePtr file;
        REQUIRE(_host->CreateFile(path, file, nullptr) == VFSError::Ok);
        REQUIRE(file->Open(VFSFlags::OF_Write) == VFSError::Ok);
        REQUIRE(file->SetUploadSize(file_size) == VFSError::Ok);
        REQUIRE(file->WriteFile(noise.data(), file_size) == VFSError::Ok);
        REQUIRE(file->Close() == VFSError::Ok);
    }
    {
        std::array<std::byte, 1000> buf; // 1Kb
        VFSFilePtr file;
        REQUIRE(_host->CreateFile(path, file, nullptr) == VFSError::Ok);
        REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
        REQUIRE(file->Read(buf.data(), buf.size()) == buf.size());
        REQUIRE(file->Close() == VFSError::Ok);
    }
    VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("aborts pending downloads", TestAbortsPendingDownloads, "nas");
INSTANTIATE_TEST("aborts pending downloads", TestAbortsPendingDownloads, "box.com");
INSTANTIATE_TEST("aborts pending downloads", TestAbortsPendingDownloads, "yandex.com");

/*==================================================================================================
empty file creation
==================================================================================================*/
static void TestEmptyFileCreation(VFSHostPtr _host)
{
    const auto path = "/empty_file";
    if( _host->Exists(path) )
        VFSEasyDelete(path, _host);

    VFSFilePtr file;
    const auto filecr_rc = _host->CreateFile(path, file, nullptr);
    REQUIRE(filecr_rc == VFSError::Ok);

    const auto open_rc = file->Open(VFSFlags::OF_Write);
    REQUIRE(open_rc == VFSError::Ok);

    REQUIRE(file->SetUploadSize(0) == VFSError::Ok);

    REQUIRE(file->Close() == VFSError::Ok);

    REQUIRE(_host->Exists(path));

    VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("empty file creation", TestEmptyFileCreation, "nas");
INSTANTIATE_TEST("empty file creation", TestEmptyFileCreation, "box.com");
INSTANTIATE_TEST("empty file creation", TestEmptyFileCreation, "yandex.com");

/*==================================================================================================
can download empty file :-|
==================================================================================================*/
static void TestEmptyFileDownload(VFSHostPtr _host)
{
    const auto path = "/temp_file";
    if( _host->Exists(path) )
        VFSEasyDelete(path, _host);
    {
        VFSFilePtr file;
        REQUIRE(_host->CreateFile(path, file, nullptr) == VFSError::Ok);
        REQUIRE(file->Open(VFSFlags::OF_Write) == VFSError::Ok);
        REQUIRE(file->SetUploadSize(0) == VFSError::Ok);
        REQUIRE(file->Close() == VFSError::Ok);
    }
    {
        VFSFilePtr file;
        REQUIRE(_host->CreateFile(path, file, nullptr) == VFSError::Ok);
        REQUIRE(file->Open(VFSFlags::OF_Read) == VFSError::Ok);
        REQUIRE(file->Close() == VFSError::Ok);
    }
    VFSEasyDelete(path, _host);
}
INSTANTIATE_TEST("can download empty file", TestEmptyFileDownload, "nas");
INSTANTIATE_TEST("can download empty file", TestEmptyFileDownload, "box.com");
INSTANTIATE_TEST("can download empty file", TestEmptyFileDownload, "yandex.com");

/*==================================================================================================
complex copy
==================================================================================================*/
static void TestComplexCopy(VFSHostPtr _host)
{
    VFSEasyDelete("/Test2", _host);
    const auto copy_rc = VFSEasyCopyDirectory(
        "/System/Library/Filesystems/msdos.fs", TestEnv().vfs_native, "/Test2", _host);
    REQUIRE(copy_rc == VFSError::Ok);

    int res = 0;
    int cmp_rc = VFSCompareNodes(
        "/System/Library/Filesystems/msdos.fs", TestEnv().vfs_native, "/Test2", _host, res);

    CHECK(cmp_rc == VFSError::Ok);
    CHECK(res == 0);

    VFSEasyDelete("/Test2", _host);
}
INSTANTIATE_TEST("complex copy", TestComplexCopy, "nas");
INSTANTIATE_TEST("complex copy", TestComplexCopy, "box.com");
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
        VFSEasyDelete(p1, _host);
        VFSEasyDelete(p2, _host);
        REQUIRE(VFSEasyCreateEmptyFile(p1, _host) == VFSError::Ok);
        REQUIRE(_host->Rename(p1, p2, nullptr) == VFSError::Ok);
        REQUIRE(_host->Exists(p1) == false);
        REQUIRE(_host->Exists(p2) == true);
        VFSEasyDelete(p2, _host);
    }
    SECTION("simple reg -> reg in other dir")
    {
        const auto p1 = "/new_empty_file";
        const auto p2 = std::filesystem::path("/TestTestDir/new_empty_file_1");
        VFSEasyDelete(p1, _host);
        VFSEasyDelete(p2.parent_path().c_str(), _host);
        REQUIRE(VFSEasyCreateEmptyFile(p1, _host) == VFSError::Ok);
        REQUIRE(_host->CreateDirectory(p2.parent_path().c_str(), 0) == VFSError::Ok);
        REQUIRE(_host->Rename(p1, p2.c_str()) == VFSError::Ok);
        REQUIRE(_host->Exists(p1) == false);
        REQUIRE(_host->Exists(p2.c_str()) == true);
        VFSEasyDelete(p2.parent_path().c_str(), _host);
    }
    SECTION("simple dir -> dir in the same dir")
    {
        const auto p1 = "/TestTestDir1";
        const auto p2 = "/TestTestDir2";
        VFSEasyDelete(p1, _host);
        VFSEasyDelete(p2, _host);
        REQUIRE(_host->CreateDirectory(p1, 0) == VFSError::Ok);
        REQUIRE(_host->Rename(p1, p2) == VFSError::Ok);
        REQUIRE(_host->Exists(p1) == false);
        REQUIRE(_host->Exists(p2) == true);
        REQUIRE(_host->IsDirectory(p2, 0) == true);
        VFSEasyDelete(p2, _host);
    }
    SECTION("simple dir -> dir in other dir")
    {
        const auto p1 = "/TestTestDir1";
        const auto p2 = "/TestTestDir2";
        const auto p3 = "/TestTestDir2/NestedDir";
        VFSEasyDelete(p1, _host);
        VFSEasyDelete(p2, _host);
        REQUIRE(_host->CreateDirectory(p1, 0) == VFSError::Ok);
        REQUIRE(_host->CreateDirectory(p2, 0) == VFSError::Ok);
        REQUIRE(_host->Rename(p1, p3) == VFSError::Ok);
        REQUIRE(_host->Exists(p1) == false);
        REQUIRE(_host->Exists(p3) == true);
        REQUIRE(_host->IsDirectory(p3, 0) == true);
        VFSEasyDelete(p2, _host);
    }
}
//INSTANTIATE_TEST("rename", TestRename, "nas"); // QNAP NAS doesn't like renaming
INSTANTIATE_TEST("rename", TestRename, "box.com");
INSTANTIATE_TEST("rename", TestRename, "yandex.com");

TEST_CASE(PREFIX "statfs on box.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnBoxComHost());

    VFSStatFS st;
    const auto statfs_rc = host->StatFS("/", st, nullptr);
    CHECK(statfs_rc == VFSError::Ok);
    CHECK(st.total_bytes > 1'000'000'000L);
}

TEST_CASE(PREFIX "invalid credentials")
{
    REQUIRE_THROWS_AS(
        new WebDAVHost("dav.box.com", g_BoxComUsername, "SomeRandomGibberish", "dav", true),
        VFSErrorException);
}

TEST_CASE(PREFIX "yandex disk acccess")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnYandexDiskHost());

    VFSStatFS st;
    const auto statfs_rc = host->StatFS("/", st, nullptr);
    REQUIRE(statfs_rc == VFSError::Ok);
    CHECK(st.total_bytes > 5'000'000'000L);
}

TEST_CASE(PREFIX "simple download from yandex disk")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnYandexDiskHost());

    VFSFilePtr file;
    const auto path = "/Bears.jpg";
    const auto filecr_rc = host->CreateFile(path, file, nullptr);
    REQUIRE(filecr_rc == VFSError::Ok);

    const auto open_rc = file->Open(VFSFlags::OF_Read);
    REQUIRE(open_rc == VFSError::Ok);

    auto data = file->ReadFile();
    REQUIRE(data);
    REQUIRE(data->size() == 1'555'830);
    REQUIRE(data->at(1'555'828) == 255);
    REQUIRE(data->at(1'555'829) == 217);
}

static std::vector<std::byte> MakeNoise(size_t size)
{
    std::vector<std::byte> noise(size);
    std::srand((int)time(0));
    for( size_t i = 0; i < size; ++i )
        noise[i] = static_cast<std::byte>(std::rand() % 256); // yes, I know that rand() is harmful!
    return noise;
}

static void
VerifyFileContent(VFSHost &_host, std::filesystem::path _path, std::span<const std::byte> _content)
{
    VFSFilePtr file;
    const auto createfile_rc = _host.CreateFile(_path.c_str(), file, nullptr);
    REQUIRE(createfile_rc == VFSError::Ok);

    const auto open_rc = file->Open(VFSFlags::OF_Read);
    REQUIRE(open_rc == VFSError::Ok);
    const auto d = file->ReadFile();
    REQUIRE(d);
    REQUIRE(d->size() == _content.size());
    REQUIRE(memcmp(d->data(), _content.data(), _content.size()) == 0);
    REQUIRE(file->Close() == VFSError::Ok);
}
