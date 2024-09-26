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
        {.mask = "*.jpg", .name = "1.jpg", .result = true},
        {.mask = "*.jpg", .name = "11.jpg", .result = true},
        {.mask = "*.jpg", .name = "1.png", .result = false},
        {.mask = "*.jpg", .name = "1png", .result = false},
        {.mask = "*.jpg", .name = ".jpg", .result = true},
        {.mask = "*.jpg", .name = "русский текст.jpg", .result = true},
        {.mask = "*.jpg", .name = "1.JPG", .result = true},
        {.mask = "*.jpg", .name = "1.jPg", .result = true},
        {.mask = "*.jpg", .name = "1.jpg1.jpg1.jpg1.jpg1.jpg1.jpg", .result = true},
        {.mask = "*.jpg", .name = "1.jpg1", .result = false},
        {.mask = "*.jpg", .name = "", .result = false},
        {.mask = "*.jpg", .name = "1", .result = false},
        {.mask = "*.jpg", .name = "jpg", .result = false},

        // two primitive *.ext masks
        {.mask = "*.jpg, *.png", .name = ".png", .result = true},
        {.mask = "*.jpg, *.png", .name = ".jpg", .result = true},
        {.mask = "*.jpg, *.png", .name = "1.png", .result = true},
        {.mask = "*.jpg, *.png", .name = "1.jpg", .result = true},
        {.mask = "*.jpg, *.png", .name = "jpg.png", .result = true},
        {.mask = "*.jpg, *.png", .name = "blah.txt", .result = false},
        {.mask = "*.jpg, *.png", .name = "blah.", .result = false},
        {.mask = "*.jpg, *.png", .name = "blah", .result = false},

        // single-character placeholder
        {.mask = "?.jpg", .name = "1.png", .result = false},
        {.mask = "?.jpg", .name = "1.jpg", .result = true},
        {.mask = "?.jpg", .name = "11.jpg", .result = false},
        {.mask = "?.jpg", .name = ".jpg", .result = false},
        {.mask = "?.jpg", .name = "png.jpg", .result = false},

        // wildcard + fixed + placeholder + fixed extension
        {.mask = "*2?.jpg", .name = "1.png", .result = false},
        {.mask = "*2?.jpg", .name = "1.jpg", .result = false},
        {.mask = "*2?.jpg", .name = "2&.jpg", .result = true},
        {.mask = "*2?.jpg", .name = "2&.png", .result = false},
        {.mask = "*2?.jpg", .name = ".jpg", .result = false},
        {.mask = "*2?.jpg", .name = "png.jpg", .result = false},
        {.mask = "*2?.jpg", .name = "672g97d6g237fg23f2*.jpg", .result = true},

        // fixed prefix + wildcard
        {.mask = "name*", .name = "name.png", .result = true},
        {.mask = "name*", .name = "name.", .result = true},
        {.mask = "name*", .name = "name", .result = true},
        {.mask = "name*", .name = "1.png", .result = false},
        {.mask = "name*", .name = "NAME1", .result = true},
        {.mask = "name*", .name = "namename", .result = true},

        // wildcard + fixed part + wildcard
        {.mask = "*abra*", .name = "abra.png", .result = true},
        {.mask = "*abra*", .name = "abra.", .result = true},
        {.mask = "*abra*", .name = ".abra", .result = true},
        {.mask = "*abra*", .name = "abra", .result = true},
        {.mask = "*abra*", .name = "ABRA", .result = true},
        {.mask = "*abra*", .name = "1.png", .result = false},
        {.mask = "*abra*", .name = "abr", .result = false},
        {.mask = "*abra*", .name = "bra", .result = false},
        {.mask = "*abra*", .name = "ABRA1", .result = true},
        {.mask = "*abra*", .name = "1ABRA1", .result = true},
        {.mask = "*abra*", .name = "ABRAABRAABRA", .result = true},

        // fixed string
        {.mask = "jpg", .name = "abra.jpg", .result = false},
        {.mask = "jpg", .name = ".jpg", .result = false},
        {.mask = "jpg", .name = "jpg", .result = true},
        {.mask = "jpg", .name = "jpg1", .result = false},
        {.mask = "jpg", .name = "JPG", .result = true},
        {.mask = "JPG", .name = "jpg", .result = true},

        // wildcard . wildcard
        {.mask = "*.*", .name = "abra.jpg", .result = true},
        {.mask = "*.*", .name = ".", .result = true},
        {.mask = "*.*", .name = "1.", .result = true},
        {.mask = "*.*", .name = ".1", .result = true},
        {.mask = "*.*", .name = "128736812763.137128736.987391273", .result = true},
        {.mask = "*.*", .name = "13123", .result = false},
        {.mask = "*.*", .name = "blah,meow", .result = false},

        // single wildcard
        {.mask = "*", .name = "a.b", .result = true},
        {.mask = "*", .name = "a.", .result = true},
        {.mask = "*", .name = "a", .result = true},
        {.mask = "*", .name = "", .result = false},

        // single placeholder
        {.mask = "?", .name = "a.b", .result = false},
        {.mask = "?", .name = "a.", .result = false},
        {.mask = "?", .name = "a", .result = true},
        {.mask = "?", .name = "", .result = false},

        // non-latin cases
        {.mask = ch(u8"*.йй"), .name = ch(u8"abra.йй"), .result = true},
        {.mask = ch(u8"*.йй"), .name = ch(u8"abra.ЙЙ"), .result = true},
        {.mask = ch(u8"*.йй"), .name = ch(u8"abra.йЙ"), .result = true},
        {.mask = ch(u8"*.йй"), .name = ch(u8"abra.Йй"), .result = true},
        {.mask = ch(u8"*.йй"), .name = ch(u8"abra.ии"), .result = false},
        {.mask = ch(u8"*.йй"), .name = ch(u8"abra.txt"), .result = false},

        // different cases
        {.mask = "a", .name = "a", .result = true},
        {.mask = "a", .name = "A", .result = true},
        {.mask = "A", .name = "a", .result = true},
        {.mask = "A", .name = "A", .result = true},

        // edge cases
        {.mask = "", .name = "", .result = false},
        {.mask = "", .name = "a", .result = false},
        {.mask = "", .name = "meow.txt", .result = false},
        {.mask = ",", .name = "", .result = false},
        {.mask = ",", .name = "a", .result = false},
        {.mask = ",", .name = "meow.txt", .result = false},
        {.mask = ",,", .name = "", .result = false},
        {.mask = ",,", .name = "a", .result = false},
        {.mask = ",,", .name = "meow.txt", .result = false},
    };

    for( auto &tc : cases ) {
        INFO(tc.mask);
        INFO(tc.name);
        const FileMask mask(tc.mask);
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
        {.mask = ".*", .name = "", .result = false},
        {.mask = ".*", .name = "a", .result = true},
        {.mask = ".*", .name = "ab", .result = true},
        {.mask = "a.*", .name = "a", .result = true},
        {.mask = "a.*", .name = "ab", .result = true},
        {.mask = "a.+", .name = "a", .result = false},
        {.mask = "a.+", .name = "ab", .result = true},
        {.mask = "a.+", .name = "ab", .result = true},
        {.mask = "(a|b)+", .name = "a", .result = true},
        {.mask = "(a|b)+", .name = "b", .result = true},
        {.mask = "(a|b)+", .name = "c", .result = false},
        {.mask = "(a|b)+", .name = "aa", .result = true},
        {.mask = "(a|b)+", .name = "ab", .result = true},
        {.mask = "(a|b)+", .name = "ac", .result = false},
        {.mask = "(meow|woof)\\.txt", .name = "a", .result = false},
        {.mask = "(meow|woof)\\.txt", .name = "meow.txt", .result = true},
        {.mask = "(meow|woof)\\.txt", .name = "woof.txt", .result = true},
        {.mask = "(meow|woof)\\.txt", .name = "blah.txt", .result = false},
    };
    for( auto &tc : cases ) {
        INFO(tc.mask);
        INFO(tc.name);
        const FileMask mask(tc.mask, FileMask::Type::RegEx);
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
