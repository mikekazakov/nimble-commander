// Copyright (C) 2014-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include "FileMask.h"

using nc::utility::FileMask;

#define PREFIX "nc::utility::FileMask "

static const char *ch(const char8_t *str)
{
    return reinterpret_cast<const char *>(str);
}

TEST_CASE(PREFIX "MatchName - old file masks")
{
    struct TC {
        const char *mask;
        const char *name;
        bool result;
    } cases[] = {
        // primitive *.ext mask
        {"*.jpg", "1.jpg", true},
        {"*.jpg", "11.jpg", true},
        {"*.jpg", "1.png", false},
        {"*.jpg", "1png", false},
        {"*.jpg", ".jpg", true},
        {"*.jpg", "русский текст.jpg", true},
        {"*.jpg", "1.JPG", true},
        {"*.jpg", "1.jPg", true},
        {"*.jpg", "1.jpg1.jpg1.jpg1.jpg1.jpg1.jpg", true},
        {"*.jpg", "1.jpg1", false},
        {"*.jpg", "", false},
        {"*.jpg", "1", false},
        {"*.jpg", "jpg", false},

        // two primitive *.ext masks
        {"*.jpg, *.png", ".png", true},
        {"*.jpg, *.png", ".jpg", true},
        {"*.jpg, *.png", "1.png", true},
        {"*.jpg, *.png", "1.jpg", true},
        {"*.jpg, *.png", "jpg.png", true},
        {"*.jpg, *.png", "blah.txt", false},
        {"*.jpg, *.png", "blah.", false},
        {"*.jpg, *.png", "blah", false},

        // single-character placeholder
        {"?.jpg", "1.png", false},
        {"?.jpg", "1.jpg", true},
        {"?.jpg", "11.jpg", false},
        {"?.jpg", ".jpg", false},
        {"?.jpg", "png.jpg", false},

        // wildcard + fixed + placeholder + fixed extension
        {"*2?.jpg", "1.png", false},
        {"*2?.jpg", "1.jpg", false},
        {"*2?.jpg", "2&.jpg", true},
        {"*2?.jpg", "2&.png", false},
        {"*2?.jpg", ".jpg", false},
        {"*2?.jpg", "png.jpg", false},
        {"*2?.jpg", "672g97d6g237fg23f2*.jpg", true},

        // fixed prefix + wildcard
        {"name*", "name.png", true},
        {"name*", "name.", true},
        {"name*", "name", true},
        {"name*", "1.png", false},
        {"name*", "NAME1", true},
        {"name*", "namename", true},

        // wildcard + fixed part + wildcard
        {"*abra*", "abra.png", true},
        {"*abra*", "abra.", true},
        {"*abra*", ".abra", true},
        {"*abra*", "abra", true},
        {"*abra*", "ABRA", true},
        {"*abra*", "1.png", false},
        {"*abra*", "abr", false},
        {"*abra*", "bra", false},
        {"*abra*", "ABRA1", true},
        {"*abra*", "1ABRA1", true},
        {"*abra*", "ABRAABRAABRA", true},

        // fixed string
        {"jpg", "abra.jpg", false},
        {"jpg", ".jpg", false},
        {"jpg", "jpg", true},
        {"jpg", "jpg1", false},
        {"jpg", "JPG", true},
        {"JPG", "jpg", true},

        // wildcard . wildcard
        {"*.*", "abra.jpg", true},
        {"*.*", ".", true},
        {"*.*", "1.", true},
        {"*.*", ".1", true},
        {"*.*", "128736812763.137128736.987391273", true},
        {"*.*", "13123", false},
        {"*.*", "blah,meow", false},

        // single wildcard
        {"*", "a.b", true},
        {"*", "a.", true},
        {"*", "a", true},
        {"*", "", false},

        // single placeholder
        {"?", "a.b", false},
        {"?", "a.", false},
        {"?", "a", true},
        {"?", "", false},

        // non-latin cases
        {ch(u8"*.йй"), ch(u8"abra.йй"), true},
        {ch(u8"*.йй"), ch(u8"abra.ЙЙ"), true},
        {ch(u8"*.йй"), ch(u8"abra.йЙ"), true},
        {ch(u8"*.йй"), ch(u8"abra.Йй"), true},
        {ch(u8"*.йй"), ch(u8"abra.ии"), false},
        {ch(u8"*.йй"), ch(u8"abra.txt"), false},

        // different cases
        {"a", "a", true},
        {"a", "A", true},
        {"A", "a", true},
        {"A", "A", true},

        // edge cases
        {"", "", false},
        {"", "a", false},
        {"", "meow.txt", false},
        {",", "", false},
        {",", "a", false},
        {",", "meow.txt", false},
        {",,", "", false},
        {",,", "a", false},
        {",,", "meow.txt", false},
    };

    for( auto &tc : cases ) {
        INFO(tc.mask);
        INFO(tc.name);
        FileMask mask(tc.mask);
        CHECK(mask.MatchName(tc.name) == tc.result);
    }
}

TEST_CASE(PREFIX "MatchName - regexes")
{
    struct TC {
        const char *mask;
        const char *name;
        bool result;
    } cases[] = {
        {".*", "", false},
        {".*", "a", true},
        {".*", "ab", true},
        {"a.*", "a", true},
        {"a.*", "ab", true},
        {"a.+", "a", false},
        {"a.+", "ab", true},
        {"a.+", "ab", true},
        {"(a|b)+", "a", true},
        {"(a|b)+", "b", true},
        {"(a|b)+", "c", false},
        {"(a|b)+", "aa", true},
        {"(a|b)+", "ab", true},
        {"(a|b)+", "ac", false},
        {"(meow|woof)\\.txt", "a", false},
        {"(meow|woof)\\.txt", "meow.txt", true},
        {"(meow|woof)\\.txt", "woof.txt", true},
        {"(meow|woof)\\.txt", "blah.txt", false},
    };
    for( auto &tc : cases ) {
        INFO(tc.mask);
        INFO(tc.name);
        FileMask mask(tc.mask, FileMask::Type::RegEx);
        CHECK(mask.MatchName(tc.name) == tc.result);
    }
}

TEST_CASE(PREFIX "Wildcards")
{
    CHECK(FileMask::IsWildCard("*.jpg") == true);
    CHECK(FileMask::IsWildCard("*") == true);
    CHECK(FileMask::IsWildCard("jpg") == false);

    CHECK(FileMask::ToExtensionWildCard("jpg") == "*.jpg");
    CHECK(FileMask::ToExtensionWildCard("jpg,png") == "*.jpg, *.png");
    CHECK(FileMask::ToFilenameWildCard("jpg") == "*jpg*");
    CHECK(FileMask::ToFilenameWildCard("jpg,png") == "*jpg*, *png*");
}
