// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include <Base/CloseFrom.h>
#include <cerrno>
#include <fcntl.h>
#include <unistd.h>

using namespace nc::base;

#define PREFIX "nc::base::CloseFrom "

static bool IsValid(int fd)
{
    return fcntl(fd, F_GETFD) != -1 || errno != EBADF;
}

TEST_CASE(PREFIX "works")
{
    int pipe_fds[2] = {-1, -1};
    REQUIRE(pipe(pipe_fds) == 0);

    // I feel lucky with numbers today
    const int fd1 = 1000;
    const int fd2 = 1500;
    REQUIRE(!IsValid(fd1));
    REQUIRE(!IsValid(fd2));

    REQUIRE(dup2(pipe_fds[0], fd1) == fd1);
    REQUIRE(dup2(pipe_fds[1], fd2) == fd2);
    REQUIRE(close(pipe_fds[0]) == 0);
    REQUIRE(close(pipe_fds[1]) == 0);

    REQUIRE(IsValid(fd1));
    REQUIRE(IsValid(fd2));

    SECTION("CloseFrom - miss all")
    {
        CloseFrom(fd2 + 1);
        REQUIRE(IsValid(fd1));
        REQUIRE(IsValid(fd2));
    }
    SECTION("CloseFrom - got one")
    {
        CloseFrom(fd2);
        REQUIRE(IsValid(fd1));
        REQUIRE(!IsValid(fd2));
    }
    SECTION("CloseFrom - got both")
    {
        CloseFrom(fd1);
        REQUIRE(!IsValid(fd1));
        REQUIRE(!IsValid(fd2));
    }
    SECTION("CloseFromExcept - miss all")
    {
        CloseFromExcept(fd2 + 1, 0);
        REQUIRE(IsValid(fd1));
        REQUIRE(IsValid(fd2));
    }
    SECTION("CloseFromExcept - got one")
    {
        CloseFromExcept(fd2, 0);
        REQUIRE(IsValid(fd1));
        REQUIRE(!IsValid(fd2));
    }
    SECTION("CloseFromExcept - got one, but skipped")
    {
        CloseFromExcept(fd2, fd2);
        REQUIRE(IsValid(fd1));
        REQUIRE(IsValid(fd2));
    }
    SECTION("CloseFromExcept - got both")
    {
        CloseFromExcept(fd1, 0);
        REQUIRE(!IsValid(fd1));
        REQUIRE(!IsValid(fd2));
    }
    SECTION("CloseFromExcept - got both, skipped first")
    {
        CloseFromExcept(fd1, fd1);
        REQUIRE(IsValid(fd1));
        REQUIRE(!IsValid(fd2));
    }
    SECTION("CloseFromExcept - got both, skipped second")
    {
        CloseFromExcept(fd1, fd2);
        REQUIRE(!IsValid(fd1));
        REQUIRE(IsValid(fd2));
    }
    SECTION("CloseFromExcept - skipp both")
    {
        CloseFromExcept(fd1, std::array<int, 2>{fd1, fd2});
        REQUIRE(IsValid(fd1));
        REQUIRE(IsValid(fd2));
    }

    close(fd1);
    close(fd2);
}
