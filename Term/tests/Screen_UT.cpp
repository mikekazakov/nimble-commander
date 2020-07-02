// Copyright (C) 2015-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Screen.h>
#include "Tests.h"

using namespace nc::term;
#define PREFIX "nc::term::Screen "

TEST_CASE(PREFIX"EraseInLine")
{
    Screen scr(10, 1);
    scr.GoTo(0, 0);
    scr.PutString("ABCDE");
    CHECK(scr.Buffer().DumpScreenAsANSI() == "ABCDE     ");
    
    scr.GoTo(3, 0);
    scr.EraseInLine(0);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "ABC       ");

    scr.GoTo(1, 0);
    scr.EraseInLine(1);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "  C       ");

    scr.EraseInLine(2);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "          ");
}

TEST_CASE(PREFIX"DoEraseScreen")
{
    Screen scr(10, 2);
    scr.GoTo(0, 0);
    scr.PutString("ABCDE");
    CHECK(scr.Buffer().DumpScreenAsANSI() == "ABCDE     "
                                             "          ");
    
    scr.GoTo(2, 0);
    scr.DoEraseScreen(1);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "   DE     "
                                             "          ");

    scr.GoTo(4, 0);
    scr.DoEraseScreen(0);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "   D      "
                                             "          ");

    scr.DoEraseScreen(2);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "          "
                                             "          ");
}

TEST_CASE(PREFIX"EraseInLineCount")
{
    Screen scr(10, 1);
    scr.GoTo(0, 0);
    scr.PutString("ABCDE");
    CHECK(scr.Buffer().DumpScreenAsANSI() == "ABCDE     ");

    scr.GoTo(2, 0);
    scr.EraseInLineCount(2);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "AB  E     ");

    scr.GoTo(2, 0);
    scr.EraseInLineCount(1000);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "AB        ");
    
    scr.GoTo(0, 0);
    scr.EraseInLineCount(1000);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "          ");
}

TEST_CASE(PREFIX"ScrollDown")
{
    Screen scr(10, 3);
    scr.GoTo(0, 0);
    scr.PutString("ABCDE");
    scr.GoTo(0, 1);
    scr.PutString("12345");
    CHECK(scr.Buffer().DumpScreenAsANSI() == "ABCDE     "
                                             "12345     "
                                             "          ");
    scr.ScrollDown(0, 3, 1);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "          "
                                             "ABCDE     "
                                             "12345     ");
    scr.ScrollDown(0, 3, 10);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "          "
                                             "          "
                                             "          ");
    
    scr.GoTo(0, 0);
    scr.PutString("ABCDE");
    scr.GoTo(0, 1);
    scr.PutString("12345");
    scr.ScrollDown(0, 3, 2);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "          "
                                             "          "
                                             "ABCDE     ");
    scr.ScrollDown(0, 2, 2);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "          "
                                             "          "
                                             "ABCDE     ");
    scr.ScrollDown(0, 2, 100);
    CHECK(scr.Buffer().DumpScreenAsANSI() == "          "
                                             "          "
                                             "ABCDE     ");
}

TEST_CASE(PREFIX"Line overflow logic")
{
    Screen scr(10, 1);
    scr.GoTo(0, 0);
    CHECK( scr.LineOverflown() == false );
    scr.PutString("01234");
    CHECK( scr.LineOverflown() == false );
    scr.PutString("56789");
    CHECK( scr.LineOverflown() == true );
    scr.GoTo(0, 0);
    CHECK( scr.LineOverflown() == false );
}
