// Copyright (C) 2019-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BriefOnDiskStorageImpl.h"
#include <Base/PosixFilesystemMock.h>
#include "UnitTests_main.h"

using namespace std::string_literals;
using namespace nc::utility;
using ::testing::_;
using ::testing::Eq;
using ::testing::Invoke;
using ::testing::Return;

TEST_CASE("BriefOnDiskStorageImpl writes the entire file")
{
    const auto data = std::string{"Hello, World!"};
    const auto expected_pattern = "/temp/dir/prefix.XXXXXX"s;
    const auto fake_path = "/temp/dir/prefix.123456"s;
    const auto fake_fd = 42;

    nc::base::PosixFilesystemMock fs;
    EXPECT_CALL(fs, mkstemp(Eq(expected_pattern))).WillOnce(Invoke([fake_path](char *p) {
        strcpy(p, fake_path.c_str());
        return fake_fd;
    }));
    EXPECT_CALL(fs, write(fake_fd, data.c_str(), data.length())).WillOnce(Return(data.length()));
    EXPECT_CALL(fs, close(fake_fd));
    EXPECT_CALL(fs, unlink(Eq(fake_path)));

    auto storage = BriefOnDiskStorageImpl{"/temp/dir/", "prefix", fs};
    auto placement = storage.Place(data.data(), data.length());
    REQUIRE(placement.has_value());
    CHECK(placement->Path() == fake_path);
}

TEST_CASE("BriefOnDiskStorageImpl renames a temp file when a specific extension is required")
{
    const auto data = std::string{"Hello, World!"};
    const auto expected_pattern = "/temp/dir/prefix.XXXXXX"s;
    const auto expected_rename = "/temp/dir/prefix.XXXXXX.txt"s;
    const auto fake_fd = 42;

    nc::base::PosixFilesystemMock fs;
    EXPECT_CALL(fs, mkstemp(_)).WillOnce(Return(fake_fd));
    EXPECT_CALL(fs, write(_, _, _)).WillOnce(Return(data.length()));
    EXPECT_CALL(fs, close(_));
    EXPECT_CALL(fs, unlink(_));
    EXPECT_CALL(fs, rename(Eq(expected_pattern), Eq(expected_rename)));

    auto storage = BriefOnDiskStorageImpl{"/temp/dir/", "prefix", fs};
    auto placement = storage.PlaceWithExtension(data.data(), data.length(), "txt");
    REQUIRE(placement.has_value());
    CHECK(placement->Path() == expected_rename);
}

TEST_CASE("BriefOnDiskStorageImpl does as many write()s as needed")
{
    const auto data = std::string{"Hello, World!"};
    const auto expected_pattern = "/temp/dir/prefix.XXXXXX"s;

    nc::base::PosixFilesystemMock fs;
    EXPECT_CALL(fs, mkstemp(_)).WillOnce(Return(42));
    EXPECT_CALL(fs, write(_, _, _)).WillOnce(Return(3)).WillOnce(Return(4)).WillOnce(Return(5)).WillOnce(Return(1));
    EXPECT_CALL(fs, close(_));
    EXPECT_CALL(fs, unlink(_));

    auto storage = BriefOnDiskStorageImpl{"/temp/dir/", "prefix", fs};
    auto placement = storage.Place(data.data(), data.length());
    REQUIRE(placement.has_value());
}
