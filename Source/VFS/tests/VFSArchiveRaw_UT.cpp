// Copyright (C) 2022-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/ArcLARaw.h>
#include <VFS/Native.h>
#include <Base/WriteAtomically.h>
#include <sys/stat.h>
#include <thread>
#include "NCE.h"

using namespace nc;
using namespace nc::vfs;

#define PREFIX "VFSArchiveRaw "

static const unsigned char __hello_txt_gz[] = {0x1f, 0x8b, 0x08, 0x08, 0xb6, 0x29, 0xef, 0x61, 0x00, 0x03, 0x68, 0x65,
                                               0x6c, 0x6c, 0x6f, 0x2e, 0x74, 0x78, 0x74, 0x00, 0xcb, 0x48, 0xcd, 0xc9,
                                               0xc9, 0x07, 0x00, 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00};
static const unsigned int __hello_txt_gz_len = 35;

static const unsigned char __hello_txt_bz2[] = {0x42, 0x5a, 0x68, 0x39, 0x31, 0x41, 0x59, 0x26, 0x53, 0x59, 0x19,
                                                0x31, 0x65, 0x3d, 0x00, 0x00, 0x00, 0x81, 0x00, 0x02, 0x44, 0xa0,
                                                0x00, 0x21, 0x9a, 0x68, 0x33, 0x4d, 0x07, 0x33, 0x8b, 0xb9, 0x22,
                                                0x9c, 0x28, 0x48, 0x0c, 0x98, 0xb2, 0x9e, 0x80};
static const unsigned int __hello_txt_bz2_len = 41;

static const unsigned char __hello_txt_zst[] =
    {0x28, 0xb5, 0x2f, 0xfd, 0x24, 0x05, 0x29, 0x00, 0x00, 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0xa3, 0x6d, 0x9f, 0x88};
static const unsigned int __hello_txt_zst_len = 18;

static const unsigned char __hello_txt_lz4[] = {0x04, 0x22, 0x4d, 0x18, 0x64, 0x40, 0xa7, 0x05, 0x00, 0x00, 0x80, 0x68,
                                                0x65, 0x6c, 0x6c, 0x6f, 0x00, 0x00, 0x00, 0x00, 0xf9, 0x77, 0x00, 0xfb};
static const unsigned int __hello_txt_lz4_len = 24;

static const unsigned char __hello_txt_lzma[] = {0x5d, 0x00, 0x00, 0x80, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff,
                                                 0xff, 0xff, 0xff, 0x00, 0x34, 0x19, 0x49, 0xee, 0x8e, 0x68,
                                                 0x21, 0xff, 0xff, 0xff, 0xb9, 0xe0, 0x00, 0x00};
static const unsigned int __hello_txt_lzma_len = 28;

static const unsigned char __hello_txt_Z[] = {0x1f, 0x9d, 0x90, 0x68, 0xca, 0xb0, 0x61, 0xf3, 0x06};
static const unsigned int __hello_txt_Z_len = 9;

static const unsigned char __hello_txt_xz[] = {
    0xfd, 0x37, 0x7a, 0x58, 0x5a, 0x00, 0x00, 0x04, 0xe6, 0xd6, 0xb4, 0x46, 0x02, 0x00, 0x21, 0x01,
    0x16, 0x00, 0x00, 0x00, 0x74, 0x2f, 0xe5, 0xa3, 0x01, 0x00, 0x04, 0x68, 0x65, 0x6c, 0x6c, 0x6f,
    0x00, 0x00, 0x00, 0x00, 0xb1, 0x37, 0xb9, 0xdb, 0xe5, 0xda, 0x1e, 0x9b, 0x00, 0x01, 0x1d, 0x05,
    0xb8, 0x2d, 0x80, 0xaf, 0x1f, 0xb6, 0xf3, 0x7d, 0x01, 0x00, 0x00, 0x00, 0x00, 0x04, 0x59, 0x5a};
static const unsigned int __hello_txt_xz_len = 64;

static const unsigned char __hello_txt_lz[] = {0x4c, 0x5a, 0x49, 0x50, 0x01, 0x0c, 0x00, 0x34, 0x19, 0x49, 0xee,
                                               0x8e, 0x68, 0x21, 0xff, 0xff, 0xff, 0xb9, 0xe0, 0x00, 0x00, 0x86,
                                               0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                               0x29, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
static const unsigned int __hello_txt_lz_len = 41;

static const unsigned char __hello_txt_lzo[] = {
    0x89, 0x4c, 0x5a, 0x4f, 0x00, 0x0d, 0x0a, 0x1a, 0x0a, 0x10, 0x40, 0x20, 0xa0, 0x09, 0x40, 0x01, 0x05,
    0x03, 0x00, 0x00, 0x01, 0x00, 0x00, 0x81, 0xa4, 0x61, 0xef, 0x29, 0xb6, 0x00, 0x00, 0x00, 0x00, 0x09,
    0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x2e, 0x74, 0x78, 0x74, 0x77, 0xac, 0x08, 0x63, 0x00, 0x00, 0x00, 0x05,
    0x00, 0x00, 0x00, 0x05, 0x06, 0x2c, 0x02, 0x15, 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x00, 0x00, 0x00, 0x00};
static const unsigned int __hello_txt_lzo_len = 68;

struct Case {
    const unsigned char *bytes;
    size_t size;
    const char *name;

} static const g_Cases[] = {{.bytes = __hello_txt_gz, .size = __hello_txt_gz_len, .name = "hello.txt.gz"},
                            {.bytes = __hello_txt_bz2, .size = __hello_txt_bz2_len, .name = "hello.txt.bz2"},
                            {.bytes = __hello_txt_zst, .size = __hello_txt_zst_len, .name = "hello.txt.zst"},
                            {.bytes = __hello_txt_lz4, .size = __hello_txt_lz4_len, .name = "hello.txt.lz4"},
                            {.bytes = __hello_txt_lzma, .size = __hello_txt_lzma_len, .name = "hello.txt.lzma"},
                            {.bytes = __hello_txt_Z, .size = __hello_txt_Z_len, .name = "hello.txt.Z"},
                            {.bytes = __hello_txt_xz, .size = __hello_txt_xz_len, .name = "hello.txt.xz"},
                            {.bytes = __hello_txt_lz, .size = __hello_txt_lz_len, .name = "hello.txt.lz"},
                            {.bytes = __hello_txt_lzo, .size = __hello_txt_lzo_len, .name = "hello.txt.lzo"}};

TEST_CASE(PREFIX "Deduces a proper filename")
{
    struct TC {
        const char *path;
        const char *expected;
    } const tcs[]{
        {.path = "hello.txt.gz", .expected = "hello.txt"},
        {.path = "/hello.txt.gz", .expected = "hello.txt"},
        {.path = "/foo/bar/hello.txt.gz", .expected = "hello.txt"},
        {.path = "hello.txt.bz2", .expected = "hello.txt"},
        {.path = "hello.txt.blah", .expected = ""},
    };
    for( auto tc : tcs )
        CHECK(ArchiveRawHost::DeduceFilename(tc.path) == tc.expected);
}

static void check(const Case &test_case)
{
    INFO(test_case.name);
    const TestDir dir;
    const auto path = std::filesystem::path(dir.directory) / test_case.name;
    REQUIRE(nc::base::WriteAtomically(path, {reinterpret_cast<const std::byte *>(test_case.bytes), test_case.size}));

    std::shared_ptr<ArchiveRawHost> host;
    REQUIRE_NOTHROW(host = std::make_shared<ArchiveRawHost>(path.c_str(), TestEnv().vfs_native));

    // let's read a file
    CHECK(host->CreateFile("").error() == Error{Error::POSIX, EINVAL});
    CHECK(host->CreateFile("blah-blah").error() == Error{Error::POSIX, EINVAL});
    CHECK(host->CreateFile("/blah-blah").error() == Error{Error::POSIX, ENOENT});

    const VFSFilePtr file = host->CreateFile("/hello.txt").value();
    CHECK(file->Open(nc::vfs::Flags::OF_Read) == VFSError::Ok);
    REQUIRE(file->Size() == 5);
    char data[5];
    CHECK(file->Read(data, 5) == 5);
    CHECK(file->Close() == VFSError::Ok);
    CHECK(std::string_view(data, 5) == "hello");

    // let's stat
    CHECK(host->Stat("", Flags::None).error() == Error{Error::POSIX, EINVAL});
    CHECK(host->Stat("blah-blah", Flags::None).error() == Error{Error::POSIX, EINVAL});
    CHECK(host->Stat("/blah-blah", Flags::None).error() == Error{Error::POSIX, ENOENT});
    const VFSStat st = host->Stat("/hello.txt", Flags::None).value();
    CHECK(st.size == 5);
    CHECK(st.mode_bits.reg);
    CHECK(st.mode_bits.rusr);
    CHECK(st.mode_bits.rgrp);

    // let's iterate
    size_t ents_encountered = 0;
    auto iter_cb = [&](const VFSDirEnt &_dirent) {
        CHECK(ents_encountered++ == 0);
        CHECK(_dirent.type == VFSDirEnt::Reg);
        CHECK(_dirent.name == std::string_view("hello.txt"));
        CHECK(_dirent.name_len == std::string_view("hello.txt").size());
        return true;
    };
    CHECK(host->IterateDirectoryListing("", iter_cb).error() == Error{Error::POSIX, EINVAL});
    CHECK(host->IterateDirectoryListing("blah-blah", iter_cb).error() == Error{Error::POSIX, EINVAL});
    CHECK(host->IterateDirectoryListing("/blah-blah", iter_cb).error() == Error{Error::POSIX, ENOENT});
    CHECK(host->IterateDirectoryListing("/", iter_cb));

    // let's fetch a listing
    CHECK(host->FetchDirectoryListing("", Flags::None).error() == Error{Error::POSIX, EINVAL});
    CHECK(host->FetchDirectoryListing("blah-blah", Flags::None).error() == Error{Error::POSIX, EINVAL});
    CHECK(host->FetchDirectoryListing("/blah-blah", Flags::None).error() == Error{Error::POSIX, ENOENT});

    {
        const VFSListingPtr listing = host->FetchDirectoryListing("/", Flags::None).value();
        CHECK(listing->Count() == 2);
        CHECK(listing->Filename(0) == "..");
        CHECK(listing->Filename(1) == "hello.txt");
        CHECK(listing->Size(0) == 5);
        CHECK(listing->Size(1) == 5);
    }

    {
        const VFSListingPtr listing = host->FetchDirectoryListing("/", Flags::F_NoDotDot).value();
        CHECK(listing->Filename(0) == "hello.txt");
        CHECK(listing->Size(0) == 5);
    }

    // check that the full verbose path is sane
    CHECK(host->MakePathVerbose("/hello.txt") == (path / "hello.txt"));
}

TEST_CASE(PREFIX "hello compressed via different compressors")
{
    for( auto &tc : g_Cases )
        check(tc);
}

TEST_CASE(PREFIX "gracefully discards non-compressed input")
{
    // clang-format off
    std::vector<uint8_t> const cases[] = {
        {},
        {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
        {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F}
    };
    // clang-format on
    const TestDir dir;
    const auto path = std::filesystem::path(dir.directory) / "gibberish.gz";
    for( const auto &tc : cases ) {
        REQUIRE(nc::base::WriteAtomically(path, {reinterpret_cast<const std::byte *>(tc.data()), tc.size()}));
        try {
            std::make_shared<ArchiveRawHost>(path.c_str(), TestEnv().vfs_native);
            CHECK(false);
        } catch( ErrorException &ex ) {
            CHECK(ex.error() == Error{VFSError::ErrorDomain, VFSError::ArclibFileFormat});
        }
    }
}
