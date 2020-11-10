// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <PathManip.h>
#include "UnitTests_main.h"

using PM = nc::utility::PathManip;
using namespace std::string_literals;
#define PREFIX "nc::utility::PathManip "

TEST_CASE(PREFIX"Filename")
{
    CHECK( PM::Filename("") == "" );
    CHECK( PM::Filename("a") == "a" );
    CHECK( PM::Filename("ab") == "ab" );
    CHECK( PM::Filename("ab.txt") == "ab.txt" );
    CHECK( PM::Filename("/ab.txt") == "ab.txt" );
    CHECK( PM::Filename("/ab.txt/") == "ab.txt" );
    CHECK( PM::Filename("/ab.txt////") == "ab.txt" );
    CHECK( PM::Filename("////ab.txt////") == "ab.txt" );
    CHECK( PM::Filename("/foo/ab.txt////") == "ab.txt" );
    CHECK( PM::Filename("/a") == "a" );
    CHECK( PM::Filename("/a/") == "a" );
    CHECK( PM::Filename("/") == "" );
    CHECK( PM::Filename("//") == "" );
    CHECK( PM::Filename("///") == "" );
    CHECK( PM::Filename("a/") == "a" );
    CHECK( PM::Filename("a//") == "a" );
    CHECK( PM::Filename("foo/a/") == "a" );
    CHECK( PM::Filename("foo/a//") == "a" );
}
