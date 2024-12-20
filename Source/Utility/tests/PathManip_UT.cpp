// Copyright (C) 2020-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <PathManip.h>
#include "UnitTests_main.h"

using PM = nc::utility::PathManip;
using namespace std::string_literals;
#define PREFIX "nc::utility::PathManip "

TEST_CASE(PREFIX "Filename")
{
    struct TC {
        std::string_view path;
        std::string_view expected;
    } const tcs[] = {
        {.path = "", .expected = ""},
        {.path = "a", .expected = "a"},
        {.path = "ab", .expected = "ab"},
        {.path = "ab.txt", .expected = "ab.txt"},
        {.path = "/ab.txt", .expected = "ab.txt"},
        {.path = "/ab.txt/", .expected = "ab.txt"},
        {.path = "/ab.txt////", .expected = "ab.txt"},
        {.path = "////ab.txt////", .expected = "ab.txt"},
        {.path = "/foo/ab.txt////", .expected = "ab.txt"},
        {.path = "/a", .expected = "a"},
        {.path = "/a/", .expected = "a"},
        {.path = "/", .expected = ""},
        {.path = "//", .expected = ""},
        {.path = "///", .expected = ""},
        {.path = "a/", .expected = "a"},
        {.path = "a//", .expected = "a"},
        {.path = "foo/a/", .expected = "a"},
        {.path = "foo/a//", .expected = "a"},
    };

    for( auto &tc : tcs )
        CHECK(PM::Filename(tc.path) == tc.expected);
}

TEST_CASE(PREFIX "Extension")
{
    struct TC {
        std::string_view path;
        std::string_view expected;
    } const tcs[] = {
        {.path = "", .expected = ""},
        {.path = "a", .expected = ""},
        {.path = "ab", .expected = ""},
        {.path = "ab.", .expected = ""},
        {.path = "ab..", .expected = ""},
        {.path = "a.b", .expected = "b"},
        {.path = "a.bc", .expected = "bc"},
        {.path = "a..bc", .expected = "bc"},
        {.path = "a..bc.", .expected = "bc."},
        {.path = "a..bc..", .expected = "bc.."},
        {.path = "ab.txt", .expected = "txt"},
        {.path = "ab.txt.", .expected = "txt."},
        {.path = "ab.txt..", .expected = "txt.."},
        {.path = ".txt", .expected = ""},
        {.path = "..txt", .expected = "txt"},
        {.path = "...txt", .expected = "txt"},
        {.path = ".", .expected = ""},
        {.path = "..", .expected = ""},
        {.path = "...", .expected = ""},
        {.path = "/ab.txt", .expected = "txt"},
        {.path = "/ab.txt/", .expected = "txt"},
        {.path = "/ab.txt////", .expected = "txt"},
        {.path = "////ab.txt////", .expected = "txt"},
        {.path = "/foo/ab.txt////", .expected = "txt"},
        {.path = "/1.txt/2////", .expected = ""},
        {.path = "/a", .expected = ""},
        {.path = "/a/", .expected = ""},
        {.path = "/", .expected = ""},
        {.path = "//", .expected = ""},
        {.path = "///", .expected = ""},
        {.path = "a/", .expected = ""},
        {.path = "a//", .expected = ""},
        {.path = "foo/a/", .expected = ""},
        {.path = "foo/a//", .expected = ""},
    };

    for( auto &tc : tcs )
        CHECK(PM::Extension(tc.path) == tc.expected);
}

TEST_CASE(PREFIX "Parent")
{
    struct TC {
        std::string_view path;
        std::string_view expected;
    } const tcs[] = {
        {.path = "", .expected = ""},
        {.path = "a", .expected = ""},
        {.path = "ab", .expected = ""},
        {.path = "ab.txt", .expected = ""},
        {.path = "/ab.txt", .expected = "/"},
        {.path = "/ab.txt/", .expected = "/"},
        {.path = "/ab.txt////", .expected = "/"},
        {.path = "////ab.txt////", .expected = "////"},
        {.path = "/foo/ab.txt////", .expected = "/foo/"},
        {.path = "/a", .expected = "/"},
        {.path = "/a/", .expected = "/"},
        {.path = "/", .expected = ""},
        {.path = "//", .expected = ""},
        {.path = "///", .expected = ""},
        {.path = "a/", .expected = ""},
        {.path = "a//", .expected = ""},
        {.path = "a/b/c", .expected = "a/b/"},
        {.path = "a/b/c/", .expected = "a/b/"},
        {.path = "a/b/c//", .expected = "a/b/"},
        {.path = "a/b/c///", .expected = "a/b/"},
        {.path = "foo/a/", .expected = "foo/"},
        {.path = "foo/a//", .expected = "foo/"},
    };
    for( auto &tc : tcs )
        CHECK(PM::Parent(tc.path) == tc.expected);
}

TEST_CASE(PREFIX "Expand")
{
    struct TC {
        std::string_view path;
        std::string_view home;
        std::string_view cwd;
        std::string_view expected;
    } const tcs[] = {
        {.path = "", .home = "", .cwd = "", .expected = ""},
        // path is an absolute
        {.path = "/", .home = "", .cwd = "", .expected = "/"},
        {.path = "/.", .home = "", .cwd = "", .expected = "/"},
        {.path = "/./", .home = "", .cwd = "", .expected = "/"},
        {.path = "/./.", .home = "", .cwd = "", .expected = "/"},
        {.path = "/..", .home = "", .cwd = "", .expected = "/"},
        {.path = "/../", .home = "", .cwd = "", .expected = "/"},
        {.path = "/../..", .home = "", .cwd = "", .expected = "/"},
        {.path = "/../../", .home = "", .cwd = "", .expected = "/"},
        {.path = "//", .home = "", .cwd = "", .expected = "/"},
        {.path = "///", .home = "", .cwd = "", .expected = "/"},
        {.path = "/a", .home = "", .cwd = "", .expected = "/a"},
        {.path = "/a/b", .home = "", .cwd = "", .expected = "/a/b"},
        {.path = "/a/..", .home = "", .cwd = "", .expected = "/"},
        {.path = "/a/../", .home = "", .cwd = "", .expected = "/"},
        {.path = "/a/b/..", .home = "", .cwd = "", .expected = "/a/"},
        {.path = "/a/b/../", .home = "", .cwd = "", .expected = "/a/"},
        // path is relative to home, no home info is available
        {.path = "~", .home = "", .cwd = "", .expected = "/"},
        {.path = "~/", .home = "", .cwd = "", .expected = "/"},
        {.path = "~/.", .home = "", .cwd = "", .expected = "/"},
        {.path = "~/./", .home = "/", .cwd = "", .expected = "/"},
        {.path = "~//", .home = "", .cwd = "", .expected = "/"},
        {.path = "~/a", .home = "", .cwd = "", .expected = "/a"},
        {.path = "~//a", .home = "", .cwd = "", .expected = "/a"},
        // path is relative to home, home info is present
        {.path = "~", .home = "/", .cwd = "", .expected = "/"},
        {.path = "~/", .home = "/", .cwd = "", .expected = "/"},
        {.path = "~/.", .home = "/", .cwd = "", .expected = "/"},
        {.path = "~/./", .home = "/", .cwd = "", .expected = "/"},
        {.path = "~//", .home = "/", .cwd = "", .expected = "/"},
        {.path = "~/a", .home = "/", .cwd = "", .expected = "/a"},
        {.path = "~", .home = "/b", .cwd = "", .expected = "/b/"},
        {.path = "~/", .home = "/b", .cwd = "", .expected = "/b/"},
        {.path = "~/.", .home = "/b", .cwd = "", .expected = "/b/"},
        {.path = "~/a", .home = "/b", .cwd = "", .expected = "/b/a"},
        {.path = "~/..", .home = "/b/a", .cwd = "", .expected = "/b/"},
        {.path = "~/../", .home = "/b/a", .cwd = "", .expected = "/b/"},
        {.path = "~/..", .home = "/b/a/", .cwd = "", .expected = "/b/"},
        {.path = "~/../", .home = "/b/a/", .cwd = "", .expected = "/b/"},
        // relative path
        {.path = "a", .home = "", .cwd = "", .expected = "/a"},
        {.path = "a", .home = "", .cwd = "/", .expected = "/a"},
        {.path = "a", .home = "", .cwd = "/b", .expected = "/b/a"},
        {.path = ".", .home = "", .cwd = "/b", .expected = "/b/"},
        {.path = "..", .home = "", .cwd = "/a/b", .expected = "/a/"},
        {.path = "../", .home = "", .cwd = "/a/b", .expected = "/a/"},
        {.path = "..", .home = "", .cwd = "/a/b/", .expected = "/a/"},
        {.path = "../", .home = "", .cwd = "/a/b/", .expected = "/a/"},
        {.path = "../c", .home = "", .cwd = "/a/b/", .expected = "/a/c"},
    };
    for( auto &tc : tcs ) {
        INFO(tc.path);
        CHECK(PM::Expand(tc.path, tc.home, tc.cwd).native() == tc.expected);
    }
}

TEST_CASE(PREFIX "EnsureTrailingSlash")
{
    struct TC {
        std::string_view path;
        std::string_view expected;
    } const tcs[] = {
        {.path = "", .expected = ""},
        {.path = "/", .expected = "/"},
        {.path = "//", .expected = "//"},
        {.path = "/a", .expected = "/a/"},
        {.path = "/a/", .expected = "/a/"},
        {.path = "/a/b", .expected = "/a/b/"},
        {.path = "/a/b/", .expected = "/a/b/"},
        {.path = "a", .expected = "a/"},
        {.path = "a/", .expected = "a/"},
    };
    for( auto &tc : tcs ) {
        INFO(tc.path);
        CHECK(PM::EnsureTrailingSlash(tc.path).native() == tc.expected);
    }
}

TEST_CASE(PREFIX "IsAbsolute")
{
    struct TC {
        std::string_view path;
        bool expected;
    } const tcs[] = {
        {.path = "", .expected = false},
        {.path = "/", .expected = true},
        {.path = "//", .expected = true},
        {.path = "/a", .expected = true},
        {.path = "/a/", .expected = true},
        {.path = "/a/b", .expected = true},
        {.path = "/a/b/", .expected = true},
        {.path = "a", .expected = false},
        {.path = "a/", .expected = false},
    };
    for( auto &tc : tcs ) {
        INFO(tc.path);
        CHECK(PM::IsAbsolute(tc.path) == tc.expected);
    }
}

TEST_CASE(PREFIX "HasTrailingSlash")
{
    struct TC {
        std::string_view path;
        bool expected;
    } const tcs[] = {
        {.path = "", .expected = false},
        {.path = "/", .expected = true},
        {.path = "//", .expected = true},
        {.path = "/a", .expected = false},
        {.path = "/a/", .expected = true},
        {.path = "/a/b", .expected = false},
        {.path = "/a/b/", .expected = true},
        {.path = "a", .expected = false},
        {.path = "a/", .expected = true},
    };
    for( auto &tc : tcs ) {
        INFO(tc.path);
        CHECK(PM::HasTrailingSlash(tc.path) == tc.expected);
    }
}

TEST_CASE(PREFIX "WithoutTrailingSlashes")
{
    struct TC {
        std::string_view path;
        std::string_view expected;
    } const tcs[] = {
        {.path = "", .expected = ""},
        {.path = "/", .expected = "/"},
        {.path = "//", .expected = "/"},
        {.path = "///", .expected = "/"},
        {.path = "/a", .expected = "/a"},
        {.path = "/a/", .expected = "/a"},
        {.path = "/a//", .expected = "/a"},
        {.path = "/a///", .expected = "/a"},
        {.path = "/a/b", .expected = "/a/b"},
        {.path = "/a/b/", .expected = "/a/b"},
        {.path = "/a/b//", .expected = "/a/b"},
        {.path = "a", .expected = "a"},
        {.path = "a/", .expected = "a"},
        {.path = "a//", .expected = "a"},
    };
    for( auto &tc : tcs ) {
        INFO(tc.path);
        CHECK(PM::WithoutTrailingSlashes(tc.path) == tc.expected);
    }
}
