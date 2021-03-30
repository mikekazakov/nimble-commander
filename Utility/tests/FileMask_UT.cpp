// Copyright (C) 2014-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include "FileMask.h"

using nc::utility::FileMask;

#define PREFIX "nc::utility::FileMask "

TEST_CASE(PREFIX "General cases")
{
    FileMask m1("*.jpg");
    CHECK(m1.MatchName("1.jpg") == true);
    CHECK(m1.MatchName("11.jpg") == true);
    CHECK(m1.MatchName("1.png") == false);
    CHECK(m1.MatchName("1png") == false);
    CHECK(m1.MatchName(".jpg") == true);
    CHECK(m1.MatchName("русский текст.jpg") == true);
    CHECK(m1.MatchName("1.JPG") == true);
    CHECK(m1.MatchName("1.jPg") == true);
    CHECK(m1.MatchName("1.jpg1.jpg1.jpg1.jpg1.jpg1.jpg") == true);
    CHECK(m1.MatchName("1.jpg1") == false);
    CHECK(m1.MatchName("") == false);
    CHECK(m1.MatchName(static_cast<char *>(nullptr)) == false);
    CHECK(m1.MatchName("1") == false);
    CHECK(m1.MatchName("jpg") == false);

    FileMask m2("*.jpg, *.png");
    CHECK(m2.MatchName("1.png") == true);
    CHECK(m2.MatchName("1.jpg") == true);
    CHECK(m2.MatchName("jpg.png") == true);

    FileMask m3("?.jpg");
    CHECK(m3.MatchName("1.png") == false);
    CHECK(m3.MatchName("1.jpg") == true);
    CHECK(m3.MatchName("11.jpg") == false);
    CHECK(m3.MatchName(".jpg") == false);
    CHECK(m3.MatchName("png.jpg") == false);

    FileMask m4("*2?.jpg");
    CHECK(m4.MatchName("1.png") == false);
    CHECK(m4.MatchName("1.jpg") == false);
    CHECK(m4.MatchName("2&.jpg") == true);
    CHECK(m4.MatchName(".jpg") == false);
    CHECK(m4.MatchName("png.jpg") == false);
    CHECK(m4.MatchName("672g97d6g237fg23f2*.jpg") == true);

    FileMask m5("name*");
    CHECK(m5.MatchName("name.png") == true);
    CHECK(m5.MatchName("name.") == true);
    CHECK(m5.MatchName("name") == true);
    CHECK(m5.MatchName("1.png") == false);
    CHECK(m5.MatchName("NAME1") == true);
    CHECK(m5.MatchName("namename") == true);

    FileMask m6("*abra*");
    CHECK(m6.MatchName("abra.png") == true);
    CHECK(m6.MatchName("abra.") == true);
    CHECK(m6.MatchName("abra") == true);
    CHECK(m6.MatchName("1.png") == false);
    CHECK(m6.MatchName("ABRA1") == true);
    CHECK(m6.MatchName("1ABRA1") == true);
    CHECK(m6.MatchName("ABRAABRAABRA") == true);

    FileMask m7("?abra?");
    CHECK(m7.MatchName("abra.png") == false);
    CHECK(m7.MatchName("abra.") == false);
    CHECK(m7.MatchName("abra") == false);
    CHECK(m7.MatchName("1.png") == false);
    CHECK(m7.MatchName("ABRA1") == false);
    CHECK(m7.MatchName("1ABRA1") == true);
    CHECK(m7.MatchName("ABRAABRAABRA") == false);

    FileMask m8("jpg");
    CHECK(m8.MatchName("abra.jpg") == false);
    CHECK(m8.MatchName(".jpg") == false);
    CHECK(m8.MatchName("jpg") == true);
    CHECK(m8.MatchName("jpg1") == false);
    CHECK(m8.MatchName("JPG") == true);

    FileMask m9("*.*");
    CHECK(m9.MatchName("abra.jpg") == true);
    CHECK(m9.MatchName(".") == true);
    CHECK(m9.MatchName("128736812763.137128736.987391273") == true);
    CHECK(m9.MatchName("13123") == false);

    FileMask m10(u8"*.йй");
    CHECK(m10.MatchName(u8"abra.йй") == true);
    CHECK(m10.MatchName(u8"abra.ЙЙ") == true);
    CHECK(m10.MatchName(u8"abra.йЙ") == true);
    CHECK(m10.MatchName(u8"abra.Йй") == true);

    CHECK(FileMask::IsWildCard("*.jpg") == true);
    CHECK(FileMask::IsWildCard("*") == true);
    CHECK(FileMask::IsWildCard("jpg") == false);

    CHECK(FileMask::ToExtensionWildCard("jpg") == "*.jpg");
    CHECK(FileMask::ToExtensionWildCard("jpg,png") == "*.jpg, *.png");
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

TEST_CASE(PREFIX "Cases")
{
    FileMask m1("a");
    CHECK(m1.MatchName("a") == true);
    CHECK(m1.MatchName("A") == true);

    FileMask m2("A");
    CHECK(m2.MatchName("a") == true);
    CHECK(m2.MatchName("A") == true);
}
