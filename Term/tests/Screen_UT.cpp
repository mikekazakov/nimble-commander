// Copyright (C) 2015-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Screen.h>
#include "Tests.h"

using namespace nc::term;
#define PREFIX "nc::term::Screen "

TEST_CASE(PREFIX"Defaults")
{
    Screen screen(10, 10);
    CHECK( screen.VideoReverse() == false );
}

TEST_CASE(PREFIX"EraseInLine")
{
    Screen screen(10, 1);
    screen.GoTo(0, 0);
    screen.PutString("ABCDE");
    CHECK(screen.Buffer().DumpScreenAsANSI() == "ABCDE     ");
    
    screen.GoTo(3, 0);
    screen.EraseInLine(0);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "ABC       ");

    screen.GoTo(1, 0);
    screen.EraseInLine(1);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "  C       ");

    screen.EraseInLine(2);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "          ");
}

TEST_CASE(PREFIX"DoEraseScreen")
{
    Screen screen(10, 2);
    screen.GoTo(0, 0);
    screen.PutString("ABCDE");
    CHECK(screen.Buffer().DumpScreenAsANSI() == "ABCDE     "
                                                "          ");
    
    screen.GoTo(2, 0);
    screen.DoEraseScreen(1);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "   DE     "
                                                "          ");

    screen.GoTo(4, 0);
    screen.DoEraseScreen(0);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "   D      "
                                                "          ");

    screen.DoEraseScreen(2);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "          "
                                                "          ");
}

TEST_CASE(PREFIX"EraseInLineCount")
{
    Screen screen(10, 1);
    screen.GoTo(0, 0);
    screen.PutString("ABCDE");
    CHECK(screen.Buffer().DumpScreenAsANSI() == "ABCDE     ");

    screen.GoTo(2, 0);
    screen.EraseInLineCount(2);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "AB  E     ");

    screen.GoTo(2, 0);
    screen.EraseInLineCount(1000);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "AB        ");
    
    screen.GoTo(0, 0);
    screen.EraseInLineCount(1000);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "          ");
}

TEST_CASE(PREFIX"ScrollDown")
{
    Screen screen(10, 3);
    screen.GoTo(0, 0);
    screen.PutString("ABCDE");
    screen.GoTo(0, 1);
    screen.PutString("12345");
    CHECK(screen.Buffer().DumpScreenAsANSI() == "ABCDE     "
                                                "12345     "
                                                "          ");
    screen.ScrollDown(0, 3, 1);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "          "
                                                "ABCDE     "
                                                "12345     ");
    screen.ScrollDown(0, 3, 10);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "          "
                                                "          "
                                                "          ");
    
    screen.GoTo(0, 0);
    screen.PutString("ABCDE");
    screen.GoTo(0, 1);
    screen.PutString("12345");
    screen.ScrollDown(0, 3, 2);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "          "
                                                "          "
                                                "ABCDE     ");
    screen.ScrollDown(0, 2, 2);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "          "
                                                "          "
                                                "ABCDE     ");
    screen.ScrollDown(0, 2, 100);
    CHECK(screen.Buffer().DumpScreenAsANSI() == "          "
                                                "          "
                                                "ABCDE     ");
}

TEST_CASE(PREFIX"Line overflow logic")
{
    Screen screen(10, 1);
    screen.GoTo(0, 0);
    CHECK( screen.LineOverflown() == false );
    screen.PutString("01234");
    CHECK( screen.LineOverflown() == false );
    screen.PutString("56789");
    CHECK( screen.LineOverflown() == true );
    screen.GoTo(0, 0);
    CHECK( screen.LineOverflown() == false );
}
