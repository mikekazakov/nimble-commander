// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "algo.h"
#include "UnitTests_main.h"

using namespace nc::base;

#define PREFIX "nc::base::"

TEST_CASE(PREFIX "SplitByDelimiters")
{
    using VS = std::vector<std::string>;
    CHECK( SplitByDelimiters("", "", true) == VS{} );
    CHECK( SplitByDelimiters("", "", false) == VS{} );
    CHECK( SplitByDelimiters("", ",", true) == VS{} );
    CHECK( SplitByDelimiters("", ",", false) == VS{} );
    CHECK( SplitByDelimiters("1", "", true) == VS{"1"} );
    CHECK( SplitByDelimiters("1", "", false) == VS{"1"} );
    CHECK( SplitByDelimiters("12", "", true) == VS{"12"} );
    CHECK( SplitByDelimiters("12", "", false) == VS{"12"} );
    CHECK( SplitByDelimiters("123", "", true) == VS{"123"} );
    CHECK( SplitByDelimiters("123", "", false) == VS{"123"} );
    CHECK( SplitByDelimiters(",1,2,3,", ",", true) == VS{"1", "2", "3"} );
    CHECK( SplitByDelimiters(",1,2,3,", ",", false) == VS{"", "1", "2", "3", ""} );
    CHECK( SplitByDelimiters(",,1,,2,,3,,", ",", true) == VS{"1", "2", "3"} );
    CHECK( SplitByDelimiters(",,1,,2,,3,,", ",", false) == VS{"", "", "1", "", "2", "", "3", "", ""} );
    CHECK( SplitByDelimiters(",", ",", true) == VS{} );
    CHECK( SplitByDelimiters(",", ",", false) == VS{"", ""} );
    CHECK( SplitByDelimiters(",,", ",", true) == VS{} );
    CHECK( SplitByDelimiters(",,", ",", false) == VS{"", "", ""} );
    CHECK( SplitByDelimiters(",1.2,3,", ",.", true) == VS{"1", "2", "3"} );
    CHECK( SplitByDelimiters(",1.2,3,", ",.", false) == VS{"", "1", "2", "3", ""} );
    CHECK( SplitByDelimiters(",,..", ",.", true) == VS{} );
    CHECK( SplitByDelimiters(",,..", ",.", false) == VS{"", "", "", "", ""} );
}

TEST_CASE(PREFIX "SplitByDelimiter")
{
    using VS = std::vector<std::string>;
    CHECK( SplitByDelimiter("", '\0', true) == VS{} );
    CHECK( SplitByDelimiter("", '\0', false) == VS{} );
    CHECK( SplitByDelimiter("", ',', true) == VS{} );
    CHECK( SplitByDelimiter("", ',', false) == VS{} );
    CHECK( SplitByDelimiter("1", '\0', true) == VS{"1"} );
    CHECK( SplitByDelimiter("1", '\0', false) == VS{"1"} );
    CHECK( SplitByDelimiter("12", '\0', true) == VS{"12"} );
    CHECK( SplitByDelimiter("12", '\0', false) == VS{"12"} );
    CHECK( SplitByDelimiter("123", '\0', true) == VS{"123"} );
    CHECK( SplitByDelimiter("123", '\0', false) == VS{"123"} );
    CHECK( SplitByDelimiter(",1,2,3,", ',', true) == VS{"1", "2", "3"} );
    CHECK( SplitByDelimiter(",1,2,3,", ',', false) == VS{"", "1", "2", "3", ""} );
    CHECK( SplitByDelimiter(",,1,,2,,3,,", ',', true) == VS{"1", "2", "3"} );
    CHECK( SplitByDelimiter(",,1,,2,,3,,", ',', false) == VS{"", "", "1", "", "2", "", "3", "", ""} );
    CHECK( SplitByDelimiter(",", ',', true) == VS{} );
    CHECK( SplitByDelimiter(",", ',', false) == VS{"", ""} );
    CHECK( SplitByDelimiter(",,", ',', true) == VS{} );
    CHECK( SplitByDelimiter(",,", ',', false) == VS{"", "", ""} );
    CHECK( SplitByDelimiter(",1.2,3,", '.', true) == VS{",1", "2,3,"} );
    CHECK( SplitByDelimiter(",1.2,3,", '.', false) == VS{",1", "2,3,"} );
    CHECK( SplitByDelimiter(".,1.2,3,.", '.', true) == VS{",1", "2,3,"} );
    CHECK( SplitByDelimiter(".,1.2,3,.", '.', false) == VS{"", ",1", "2,3,", ""} );
}

TEST_CASE(PREFIX "ReplaceAll(..., std::string_view, ...)")
{
    CHECK( ReplaceAll("", "", "") == "" );
    CHECK( ReplaceAll("a", "", "") == "a" );
    CHECK( ReplaceAll("a", "", "b") == "a" );
    CHECK( ReplaceAll("a", "b", "c") == "a" );
    CHECK( ReplaceAll("a", "a", "b") == "b" );
    CHECK( ReplaceAll("a", "a", "") == "" );
    CHECK( ReplaceAll("aaaa", "a", "") == "" );
    CHECK( ReplaceAll("aaaa", "a", "b") == "bbbb" );
    CHECK( ReplaceAll("aaaa", "aa", "b") == "bb" );
    CHECK( ReplaceAll("aaaaa", "aa", "b") == "bba" );
    CHECK( ReplaceAll("a", "aa", "b") == "a" );
    CHECK( ReplaceAll("aaaaa", "aa", "") == "a" );
    CHECK( ReplaceAll("aaaaa", "a", "bb") == "bbbbbbbbbb" );
    CHECK( ReplaceAll("aaaaa", "", "bb") == "aaaaa" );
}
