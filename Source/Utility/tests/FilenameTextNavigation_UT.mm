// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include "FilenameTextNavigation.h"

using nc::utility::FilenameTextNavigation;

#define PREFIX "FilenameTextNavigation "

TEST_CASE(PREFIX "Forward 1")
{
    const auto text = @"filename.txt";
    // 0123456789012
    const auto test = [](NSString *test, unsigned long pos) {
        return FilenameTextNavigation::NavigateToNextWord(test, pos);
    };
    CHECK(test(text, 0) == 8);
    CHECK(test(text, 7) == 8);
    CHECK(test(text, 8) == 12);
    CHECK(test(text, 9) == 12);
    CHECK(test(text, 12) == 12);
}

TEST_CASE(PREFIX "Forward 2")
{
    const auto text = @"file-name   with.a,many_many/parts.txt";
    // 012345678901234567890123456789012345678
    const auto test = [](NSString *test, unsigned long pos) {
        return FilenameTextNavigation::NavigateToNextWord(test, pos);
    };
    CHECK(test(text, 0) == 4);
    CHECK(test(text, 4) == 9);
    CHECK(test(text, 9) == 16);
    CHECK(test(text, 16) == 18);
    CHECK(test(text, 18) == 23);
    CHECK(test(text, 23) == 28);
    CHECK(test(text, 28) == 34);
    CHECK(test(text, 34) == 38);
    CHECK(test(text, 38) == 38);
}

TEST_CASE(PREFIX "Forward 3")
{
    const auto text = @"________";
    // 012345678
    const auto test = [](NSString *test, unsigned long pos) {
        return FilenameTextNavigation::NavigateToNextWord(test, pos);
    };
    CHECK(test(text, 0) == 8);
    CHECK(test(text, 1) == 8);
    CHECK(test(text, 7) == 8);
    CHECK(test(text, 8) == 8);
}

TEST_CASE(PREFIX "Forward 4")
{
    const auto text = @"abcdefg";
    // 01234567
    const auto test = [](NSString *test, unsigned long pos) {
        return FilenameTextNavigation::NavigateToNextWord(test, pos);
    };
    CHECK(test(text, 0) == 7);
    CHECK(test(text, 1) == 7);
    CHECK(test(text, 6) == 7);
    CHECK(test(text, 7) == 7);
}

TEST_CASE(PREFIX "Backward 1")
{
    const auto text = @"filename.txt";
    // 0123456789012
    const auto test = [](NSString *test, unsigned long pos) {
        return FilenameTextNavigation::NavigateToPreviousWord(test, pos);
    };
    CHECK(test(text, 0) == 0);
    CHECK(test(text, 7) == 0);
    CHECK(test(text, 8) == 0);
    CHECK(test(text, 9) == 0);
    CHECK(test(text, 11) == 9);
    CHECK(test(text, 12) == 9);
}

TEST_CASE(PREFIX "Backward 2")
{
    const auto text = @"file-name   with.a,many_many/parts.txt";
    // 012345678901234567890123456789012345678
    const auto test = [](NSString *test, unsigned long pos) {
        return FilenameTextNavigation::NavigateToPreviousWord(test, pos);
    };
    CHECK(test(text, 0) == 0);
    CHECK(test(text, 5) == 0);
    CHECK(test(text, 12) == 5);
    CHECK(test(text, 16) == 12);
    CHECK(test(text, 17) == 12);
    CHECK(test(text, 24) == 19);
    CHECK(test(text, 29) == 24);
    CHECK(test(text, 35) == 29);
    CHECK(test(text, 38) == 35);
}

TEST_CASE(PREFIX "Backward 3")
{
    const auto text = @"________";
    // 012345678
    const auto test = [](NSString *test, unsigned long pos) {
        return FilenameTextNavigation::NavigateToPreviousWord(test, pos);
    };
    CHECK(test(text, 0) == 0);
    CHECK(test(text, 1) == 0);
    CHECK(test(text, 7) == 0);
    CHECK(test(text, 8) == 0);
}

TEST_CASE(PREFIX "Backward 4")
{
    const auto text = @"abcdefg";
    // 01234567
    const auto test = [](NSString *test, unsigned long pos) {
        return FilenameTextNavigation::NavigateToPreviousWord(test, pos);
    };
    CHECK(test(text, 0) == 0);
    CHECK(test(text, 1) == 0);
    CHECK(test(text, 6) == 0);
    CHECK(test(text, 7) == 0);
}

TEST_CASE(PREFIX "Empty")
{
    CHECK(FilenameTextNavigation::NavigateToNextWord(@"", 0) == 0);
    CHECK(FilenameTextNavigation::NavigateToPreviousWord(@"", 0) == 0);
}
