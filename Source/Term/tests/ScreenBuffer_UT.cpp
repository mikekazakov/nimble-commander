// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.

#include "Tests.h"

#include <ScreenBuffer.h>

using namespace nc::term;
#define PREFIX "nc::term::ScreenBuffer "

TEST_CASE(PREFIX "Init")
{
    SECTION("Normal case")
    {
        ScreenBuffer buffer(3, 4);
        REQUIRE(buffer.Width() == 3);
        REQUIRE(buffer.Height() == 4);
        buffer.LineFromNo(0).front().l = 'A';
        buffer.LineFromNo(3).back().l = 'B';
        REQUIRE(buffer.DumpScreenAsANSI() == "A  "
                                             "   "
                                             "   "
                                             "  B");
        REQUIRE(buffer.LineWrapped(3) == false);
        buffer.SetLineWrapped(3, true);
        REQUIRE(buffer.LineWrapped(3) == true);
    }
    SECTION("Empty buffer")
    {
        ScreenBuffer buffer(0, 0);
        REQUIRE(buffer.Width() == 0);
        REQUIRE(buffer.Height() == 0);
        auto l1 = buffer.LineFromNo(0);
        REQUIRE(l1.empty());
        auto l2 = buffer.LineFromNo(10);
        REQUIRE(l2.empty());
        auto l3 = buffer.LineFromNo(-1);
        REQUIRE(l3.empty());
    }
    SECTION("Zero width")
    {
        ScreenBuffer buffer(0, 2);
        REQUIRE(buffer.Width() == 0);
        REQUIRE(buffer.Height() == 2);
        auto l1 = buffer.LineFromNo(0);
        auto l2 = buffer.LineFromNo(1);
        REQUIRE(l1.data() == l1.data());
        REQUIRE(l1.size() == 0);
        REQUIRE(l2.size() == 0);
    }
}

TEST_CASE(PREFIX "ComposeContinuousLines")
{
    ScreenBuffer buffer(3, 4);
    buffer.LineFromNo(0).back().l = 'A';
    buffer.LineFromNo(2).back().l = 'B';
    REQUIRE(buffer.DumpScreenAsANSI() == "  A"
                                         "   "
                                         "  B"
                                         "   ");

    auto cl1 = buffer.ComposeContinuousLines(0, 4);
    REQUIRE(cl1.size() == 4);
    REQUIRE(cl1[0].size() == 3);
    REQUIRE(cl1[0].at(2).l == 'A');
    REQUIRE(cl1[2].size() == 3);
    REQUIRE(cl1[2].at(2).l == 'B');

    buffer.SetLineWrapped(0, true);
    auto cl2 = buffer.ComposeContinuousLines(0, 4);
    REQUIRE(cl2.size() == 3);
    REQUIRE(cl2[0].size() == 3);
    REQUIRE(cl2[0].at(2).l == 'A');
    REQUIRE(cl2[1].size() == 3);
    REQUIRE(cl2[1].at(2).l == 'B');

    buffer.SetLineWrapped(1, true);
    auto cl3 = buffer.ComposeContinuousLines(0, 4);
    REQUIRE(cl3.size() == 2);
    REQUIRE(cl3[0].size() == 6);
    REQUIRE(cl3[0].at(2).l == 'A');
    REQUIRE(cl3[0].at(4).l == 0);
    REQUIRE(cl3[0].at(5).l == 'B');
}

TEST_CASE(PREFIX "Space::HaveSameAttributes")
{
    ScreenBuffer::Space s1, s2;
    std::memset(&s1, 0, sizeof(s1));
    std::memset(&s2, 0, sizeof(s2));
    SECTION("")
    {
        CHECK(s1.HaveSameAttributes(s2));
    }
    SECTION("")
    {
        s1.l = 'a';
        s2.l = 'b';
        CHECK(s1.HaveSameAttributes(s2));
    }
    SECTION("")
    {
        s1.customfg = true;
        CHECK(!s1.HaveSameAttributes(s2));
    }
    SECTION("")
    {
        s1.custombg = true;
        CHECK(!s1.HaveSameAttributes(s2));
    }
    SECTION("")
    {
        s1.faint = true;
        CHECK(!s1.HaveSameAttributes(s2));
    }
    SECTION("")
    {
        s1.underline = true;
        CHECK(!s1.HaveSameAttributes(s2));
    }
    SECTION("")
    {
        s1.crossed = true;
        CHECK(!s1.HaveSameAttributes(s2));
    }
    SECTION("")
    {
        s1.bold = true;
        CHECK(!s1.HaveSameAttributes(s2));
    }
    SECTION("")
    {
        s1.italic = true;
        CHECK(!s1.HaveSameAttributes(s2));
    }
    SECTION("")
    {
        s1.invisible = true;
        CHECK(!s1.HaveSameAttributes(s2));
    }
    SECTION("")
    {
        s1.blink = true;
        CHECK(!s1.HaveSameAttributes(s2));
    }
    SECTION("")
    {
        (*static_cast<uint64_t *>(static_cast<void *>(&s1))) |= (1ULL << 58);
        CHECK(s1.HaveSameAttributes(s2));
        (*static_cast<uint64_t *>(static_cast<void *>(&s1))) |= (1ULL << 63);
        CHECK(s1.HaveSameAttributes(s2));
    }
}
