// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include "../source/NetWebDAV/WebDAVHost.h"
#include <VFS/VFSEasyOps.h>
#include <VFS/Native.h>
#include "NCE.h"
#include <sys/stat.h>
#include <span>

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

TEST_CASE(PREFIX "simple file write on box.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnBoxComHost());

    VFSFilePtr file;
    const auto path = "/temp_file";
    const auto filecr_rc = host->CreateFile(path, file, nullptr);
    REQUIRE(filecr_rc == VFSError::Ok);

    const auto open_rc = file->Open(VFSFlags::OF_Write);
    REQUIRE(open_rc == VFSError::Ok);

    std::string_view str{"Hello, world!"};
    file->SetUploadSize(str.size());
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

    VFSEasyDelete(path, host);
}

TEST_CASE(PREFIX "various complete writes on box.com")
{
    VFSHostPtr host = spawnBoxComHost();

    const auto path = "/temp_file";
    if( host->Exists(path) )
        VFSEasyDelete(path, host);

    VFSFilePtr file;
    const auto filecr_rc = host->CreateFile(path, file, nullptr);
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

    VerifyFileContent(*host, path, noise);
    
    VFSEasyDelete(path, host);
}

TEST_CASE(PREFIX "edge case - 1b writes on box.com")
{
    VFSHostPtr host = spawnBoxComHost();

    const auto path = "/temp_file";
    if( host->Exists(path) )
        VFSEasyDelete(path, host);

    VFSFilePtr file;
    const auto filecr_rc = host->CreateFile(path, file, nullptr);
    REQUIRE(filecr_rc == VFSError::Ok);

    const auto open_rc = file->Open(VFSFlags::OF_Write);
    REQUIRE(open_rc == VFSError::Ok);

    constexpr size_t file_size = 9;
    char data[file_size+1] = "012345678";
    file->SetUploadSize(file_size);
    for(int i = 0; i != file_size; ++i)
        REQUIRE(file->Write(data + i, 1) == 1);
    
    REQUIRE(file->Close() == VFSError::Ok);
    
    VerifyFileContent(*host, path, {reinterpret_cast<std::byte*>(data), file_size});
    
    VFSEasyDelete(path, host);
}

TEST_CASE(PREFIX "empty file creation on box.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnBoxComHost());

    VFSFilePtr file;
    const auto path = "/empty_file";
    const auto filecr_rc = host->CreateFile(path, file, nullptr);
    REQUIRE(filecr_rc == VFSError::Ok);

    const auto open_rc = file->Open(VFSFlags::OF_Write);
    REQUIRE(open_rc == VFSError::Ok);

    file->SetUploadSize(0);

    REQUIRE(file->Close() == VFSError::Ok);

    REQUIRE(host->Exists(path));

    VFSEasyDelete(path, host);
}

TEST_CASE(PREFIX "complex copy to box.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnBoxComHost());

    VFSEasyDelete("/Test2", host);
    const auto copy_rc = VFSEasyCopyDirectory(
        "/System/Library/Filesystems/msdos.fs", TestEnv().vfs_native, "/Test2", host);
    REQUIRE(copy_rc == VFSError::Ok);

    int res = 0;
    int cmp_rc = VFSCompareNodes(
        "/System/Library/Filesystems/msdos.fs", TestEnv().vfs_native, "/Test2", host, res);

    CHECK(cmp_rc == VFSError::Ok);
    CHECK(res == 0);

    VFSEasyDelete("/Test2", host);
}

TEST_CASE(PREFIX "rename on box.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnBoxComHost());

    const auto p1 = "/new_empty_file";
    const auto creat_rc = VFSEasyCreateEmptyFile(p1, host);
    CHECK(creat_rc == VFSError::Ok);

    const auto p2 = reinterpret_cast<const char *>(u8"/new_empty_file_тест_ееёёё");
    const auto rename_rc = host->Rename(p1, p2, nullptr);
    CHECK(rename_rc == VFSError::Ok);

    CHECK(host->Exists(p2));

    VFSEasyDelete(p2, host);
}

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

TEST_CASE(PREFIX "complex copy to yandex disk")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = spawnYandexDiskHost());

    VFSEasyDelete("/Test2", host);
    const auto copy_rc = VFSEasyCopyDirectory(
        "/System/Library/Filesystems/msdos.fs", TestEnv().vfs_native, "/Test2", host);
    REQUIRE(copy_rc == VFSError::Ok);

    int res = 0;
    int cmp_rc = VFSCompareNodes(
        "/System/Library/Filesystems/msdos.fs", TestEnv().vfs_native, "/Test2", host, res);

    REQUIRE(cmp_rc == VFSError::Ok);
    REQUIRE(res == 0);

    VFSEasyDelete("/Test2", host);
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
