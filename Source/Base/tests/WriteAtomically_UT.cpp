// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WriteAtomically.h"
#include "UnitTests_main.h"
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>

using nc::base::WriteAtomically;
using VP = std::vector<std::filesystem::path>;

#define PREFIX "WriteAtomically "

static std::optional<std::vector<std::byte>> ReadFile(const std::filesystem::path &_path)
{
    const int fd = open(_path.c_str(), O_RDONLY);
    if( fd < 0 )
        return std::nullopt;

    const long size = lseek(fd, 0, SEEK_END);
    lseek(fd, 0, SEEK_SET);

    auto buf = std::vector<std::byte>(size);

    std::byte *buftmp = buf.data();
    uint64_t szleft = size;
    while( szleft ) {
        const ssize_t r = read(fd, buftmp, szleft);
        if( r < 0 ) {
            close(fd);
            return std::nullopt;
        }
        szleft -= r;
        buftmp += r;
    }

    close(fd);
    return std::move(buf);
}

static std::vector<std::byte> FromString(const std::string_view _str)
{
    return {reinterpret_cast<const std::byte *>(_str.data()),
            reinterpret_cast<const std::byte *>(_str.data()) + _str.size()};
}

TEST_CASE(PREFIX "Simple cases")
{
    TempTestDir d;
    const std::filesystem::path target = d.directory / "test";
    SECTION("File didn't exist, writing non-zero data")
    {
        const std::vector<std::byte> payload = FromString("Hello, World!");
        REQUIRE(WriteAtomically(target, payload));
        REQUIRE(ReadFile(target) == payload);
    }
    SECTION("File didn't exist, writing zero data")
    {
        const std::vector<std::byte> payload;
        REQUIRE(WriteAtomically(target, payload));
        REQUIRE(ReadFile(target) == payload);
    }
    SECTION("Overwriting an existing file")
    {
        const std::vector<std::byte> payload1 = FromString("Meow");
        REQUIRE(WriteAtomically(target, payload1));
        const std::vector<std::byte> payload2 = FromString("Hiss");
        REQUIRE(WriteAtomically(target, payload2));
        REQUIRE(ReadFile(target) == payload2);
    }
}

TEST_CASE(PREFIX "Error handling")
{
    const std::vector<std::byte> payload = FromString("Hello, World!");
    const auto err = WriteAtomically("/bin/meow", payload);
    CHECK(err.error() == nc::Error{nc::Error::POSIX, EPERM});
}
