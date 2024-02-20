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
        {"", ""},
        {"a", "a"},
        {"ab", "ab"},
        {"ab.txt", "ab.txt"},
        {"/ab.txt", "ab.txt"},
        {"/ab.txt/", "ab.txt"},
        {"/ab.txt////", "ab.txt"},
        {"////ab.txt////", "ab.txt"},
        {"/foo/ab.txt////", "ab.txt"},
        {"/a", "a"},
        {"/a/", "a"},
        {"/", ""},
        {"//", ""},
        {"///", ""},
        {"a/", "a"},
        {"a//", "a"},
        {"foo/a/", "a"},
        {"foo/a//", "a"},
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
        {"", ""},
        {"a", ""},
        {"ab", ""},
        {"ab.", ""},
        {"ab..", ""},
        {"a.b", "b"},
        {"a.bc", "bc"},
        {"a..bc", "bc"},
        {"a..bc.", "bc."},
        {"a..bc..", "bc.."},
        {"ab.txt", "txt"},
        {"ab.txt.", "txt."},
        {"ab.txt..", "txt.."},
        {".txt", ""},
        {"..txt", "txt"},
        {"...txt", "txt"},
        {".", ""},
        {"..", ""},
        {"...", ""},
        {"/ab.txt", "txt"},
        {"/ab.txt/", "txt"},
        {"/ab.txt////", "txt"},
        {"////ab.txt////", "txt"},
        {"/foo/ab.txt////", "txt"},
        {"/1.txt/2////", ""},
        {"/a", ""},
        {"/a/", ""},
        {"/", ""},
        {"//", ""},
        {"///", ""},
        {"a/", ""},
        {"a//", ""},
        {"foo/a/", ""},
        {"foo/a//", ""},
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
        {"", ""},
        {"a", ""},
        {"ab", ""},
        {"ab.txt", ""},
        {"/ab.txt", "/"},
        {"/ab.txt/", "/"},
        {"/ab.txt////", "/"},
        {"////ab.txt////", "////"},
        {"/foo/ab.txt////", "/foo/"},
        {"/a", "/"},
        {"/a/", "/"},
        {"/", ""},
        {"//", ""},
        {"///", ""},
        {"a/", ""},
        {"a//", ""},
        {"foo/a/", "foo/"},
        {"foo/a//", "foo/"},
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
        {"", "", "", ""},
        // path is an absolute
        {"/", "", "", "/"},
        {"/.", "", "", "/"},
        {"/./", "", "", "/"},
        {"/./.", "", "", "/"},
        {"/..", "", "", "/"},
        {"/../", "", "", "/"},
        {"/../..", "", "", "/"},
        {"/../../", "", "", "/"},
        {"//", "", "", "/"},
        {"///", "", "", "/"},
        {"/a", "", "", "/a"},
        {"/a/b", "", "", "/a/b"},
        {"/a/..", "", "", "/"},
        {"/a/../", "", "", "/"},
        {"/a/b/..", "", "", "/a/"},
        {"/a/b/../", "", "", "/a/"},
        // path is relative to home, no home info is available
        {"~", "", "", "/"},
        {"~/", "", "", "/"},
        {"~/.", "", "", "/"},
        {"~/./", "/", "", "/"},
        {"~//", "", "", "/"},
        {"~/a", "", "", "/a"},
        {"~//a", "", "", "/a"},
        // path is relative to home, home info is present
        {"~", "/", "", "/"},
        {"~/", "/", "", "/"},
        {"~/.", "/", "", "/"},
        {"~/./", "/", "", "/"},
        {"~//", "/", "", "/"},
        {"~/a", "/", "", "/a"},
        {"~", "/b", "", "/b/"},
        {"~/", "/b", "", "/b/"},
        {"~/.", "/b", "", "/b/"},
        {"~/a", "/b", "", "/b/a"},
        {"~/..", "/b/a", "", "/b/"},
        {"~/../", "/b/a", "", "/b/"},
        {"~/..", "/b/a/", "", "/b/"},
        {"~/../", "/b/a/", "", "/b/"},
        // relative path
        {"a", "", "", "/a"},
        {"a", "", "/", "/a"},
        {"a", "", "/b", "/b/a"},
        {".", "", "/b", "/b/"},
        {"..", "", "/a/b", "/a/"},
        {"../", "", "/a/b", "/a/"},
        {"..", "", "/a/b/", "/a/"},
        {"../", "", "/a/b/", "/a/"},
        {"../c", "", "/a/b/", "/a/c"},
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
        {"", ""},
        {"/", "/"},
        {"//", "//"},
        {"/a", "/a/"},
        {"/a/", "/a/"},
        {"/a/b", "/a/b/"},
        {"/a/b/", "/a/b/"},
        {"a", "a/"},
        {"a/", "a/"},
    };
    for( auto &tc : tcs ) {
        INFO(tc.path);
        CHECK(PM::EnsureTrailingSlash(tc.path).native() == tc.expected);
    }
}
