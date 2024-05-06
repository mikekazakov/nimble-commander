// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <InputTranslatorImpl.h>
#include "Tests.h"

using namespace nc::term;
using namespace std::string_literals;
using MouseEvent = InputTranslator::MouseEvent;
#define PREFIX "nc::term::InputTranslatorImpl "

TEST_CASE(PREFIX "Mouse reporting: X10")
{
    std::string output;
    InputTranslatorImpl it;
    it.SetOuput([&output](std::span<const std::byte> _bytes) {
        output.assign(reinterpret_cast<const char *>(_bytes.data()), _bytes.size());
    });
    it.SetMouseReportingMode(InputTranslator::MouseReportingMode::X10);

    MouseEvent event;
    event.type = MouseEvent::LDown;

    auto expect = [&](const std::string &_expected) {
        it.ProcessMouseEvent(event);
        CHECK(output == _expected);
    };

    SECTION("LB down, (0,0)")
    {
        event.type = MouseEvent::LDown;
        event.x = 0;
        event.y = 0;
        expect("\x1B[M !!");
    }
    SECTION("LB up, (0,0)")
    {
        event.type = MouseEvent::LUp;
        event.x = 0;
        event.y = 0;
        expect("\x1B[M#!!");
    }
    SECTION("MB down, (0,0)")
    {
        event.type = MouseEvent::MDown;
        event.x = 0;
        event.y = 0;
        expect("\x1B[M!!!");
    }
    SECTION("RB down, (10,20)")
    {
        event.type = MouseEvent::RDown;
        event.x = 10;
        event.y = 20;
        expect("\x1B[M\"+5");
    }
    SECTION("Limits: -1, -1")
    {
        event.x = -1;
        event.y = -1;
        expect("\x1B[M !!");
    }
    SECTION("Limits: 222, 222")
    {
        event.x = 222;
        event.y = 222;
        expect("\x1B[M \xFF\xFF");
    }
    SECTION("Limits: 223, 223")
    {
        event.x = 223;
        event.y = 223;
        expect("\x1B[M \xFF\xFF");
    }
}

TEST_CASE(PREFIX "Mouse reporting: Normal")
{
    std::string output;
    InputTranslatorImpl it;
    it.SetOuput([&output](std::span<const std::byte> _bytes) {
        output.assign(reinterpret_cast<const char *>(_bytes.data()), _bytes.size());
    });
    it.SetMouseReportingMode(InputTranslator::MouseReportingMode::Normal);

    MouseEvent event;
    event.type = MouseEvent::LDown;

    auto expect = [&](const std::string &_expected) {
        it.ProcessMouseEvent(event);
        CHECK(output == _expected);
    };

    SECTION("LB down, (0,0)")
    {
        event.type = MouseEvent::LDown;
        expect("\x1B[M !!");
    }
    SECTION("LB up, (0,0)")
    {
        event.type = MouseEvent::LUp;
        expect("\x1B[M#!!");
    }
    SECTION("LB drag, (0,0)")
    {
        event.type = MouseEvent::LDrag;
        expect("\x1B[M@!!");
    }
    SECTION("MB down, (0,0)")
    {
        event.type = MouseEvent::MDown;
        expect("\x1B[M!!!");
    }
    SECTION("MB up, (0,0)")
    {
        event.type = MouseEvent::MUp;
        expect("\x1B[M#!!");
    }
    SECTION("MB drag, (0,0)")
    {
        event.type = MouseEvent::MDrag;
        expect("\x1B[MA!!");
    }
    SECTION("RB down, (10,20)")
    {
        event.type = MouseEvent::RDown;
        event.x = 10;
        event.y = 20;
        expect("\x1B[M\"+5");
    }
    SECTION("RB up, (0,0)")
    {
        event.type = MouseEvent::RUp;
        expect("\x1B[M#!!");
    }
    SECTION("RB drag, (0,0)")
    {
        event.type = MouseEvent::RDrag;
        expect("\x1B[MB!!");
    }
    SECTION("Limits: -1, -1")
    {
        event.x = -1;
        event.y = -1;
        expect("\x1B[M !!");
    }
    SECTION("Limits: 222, 222")
    {
        event.x = 222;
        event.y = 222;
        expect("\x1B[M \xFF\xFF");
    }
    SECTION("Limits: 223, 223")
    {
        event.x = 223;
        event.y = 223;
        expect("\x1B[M \xFF\xFF");
    }
    SECTION("Shift")
    {
        event.shift = true;
        expect("\x1B[M$!!");
    }
    SECTION("Alt")
    {
        event.alt = true;
        expect("\x1B[M(!!");
    }
    SECTION("Control")
    {
        event.control = true;
        expect("\x1B[M0!!");
    }
    SECTION("All")
    {
        event.shift = true;
        event.alt = true;
        event.control = true;
        expect("\x1B[M<!!");
    }
    SECTION("Motion")
    {
        event.type = MouseEvent::Motion;
        expect("\x1B[MC!!");
    }
}

TEST_CASE(PREFIX "Mouse reporting: UTF8")
{
    std::string output;
    InputTranslatorImpl it;
    it.SetOuput([&output](std::span<const std::byte> _bytes) {
        output.assign(reinterpret_cast<const char *>(_bytes.data()), _bytes.size());
    });
    it.SetMouseReportingMode(InputTranslator::MouseReportingMode::UTF8);

    MouseEvent event;
    event.type = MouseEvent::LDown;

    auto expect = [&](const std::string &_expected) {
        it.ProcessMouseEvent(event);
        CHECK(output == _expected);
    };

    SECTION("LB down, (0,0)")
    {
        event.type = MouseEvent::LDown;
        expect("\x1B[M !!");
    }
    SECTION("LB up, (0,0)")
    {
        event.type = MouseEvent::LUp;
        expect("\x1B[M#!!");
    }
    SECTION("LB drag, (0,0)")
    {
        event.type = MouseEvent::LDrag;
        expect("\x1B[M@!!");
    }
    SECTION("MB down, (0,0)")
    {
        event.type = MouseEvent::MDown;
        expect("\x1B[M!!!");
    }
    SECTION("MB up, (0,0)")
    {
        event.type = MouseEvent::MUp;
        expect("\x1B[M#!!");
    }
    SECTION("MB drag, (0,0)")
    {
        event.type = MouseEvent::MDrag;
        expect("\x1B[MA!!");
    }
    SECTION("RB down, (10,20)")
    {
        event.type = MouseEvent::RDown;
        event.x = 10;
        event.y = 20;
        expect("\x1B[M\"+5");
    }
    SECTION("RB up, (0,0)")
    {
        event.type = MouseEvent::RUp;
        expect("\x1B[M#!!");
    }
    SECTION("RB drag, (0,0)")
    {
        event.type = MouseEvent::RDrag;
        expect("\x1B[MB!!");
    }
    SECTION("Limits: -1, -1")
    {
        event.x = -1;
        event.y = -1;
        expect("\x1B[M !!");
    }
    SECTION("Limits: 222, 222")
    {
        event.x = 222;
        event.y = 222;
        expect("\x1B[M \xC3\xBF\xC3\xBF");
    }
    SECTION("Limits: 223, 223")
    {
        event.x = 223;
        event.y = 223;
        expect("\x1B[M \xC4\x80\xC4\x80");
    }
    SECTION("Limits: 2014, 2014")
    {
        event.x = 2014;
        event.y = 2014;
        expect("\x1B[M \xDF\xBF\xDF\xBF");
    }
    SECTION("Limits: 2015, 2015")
    {
        event.x = 2015;
        event.y = 2015;
        expect("\x1B[M \xDF\xBF\xDF\xBF");
    }
    SECTION("Shift")
    {
        event.shift = true;
        expect("\x1B[M$!!");
    }
    SECTION("Alt")
    {
        event.alt = true;
        expect("\x1B[M(!!");
    }
    SECTION("Control")
    {
        event.control = true;
        expect("\x1B[M0!!");
    }
    SECTION("All")
    {
        event.shift = true;
        event.alt = true;
        event.control = true;
        expect("\x1B[M<!!");
    }
    SECTION("Motion")
    {
        event.type = MouseEvent::Motion;
        expect("\x1B[MC!!");
    }
}

TEST_CASE(PREFIX "Mouse reporting: SGR")
{
    std::string output;
    InputTranslatorImpl it;
    it.SetOuput([&output](std::span<const std::byte> _bytes) {
        output.assign(reinterpret_cast<const char *>(_bytes.data()), _bytes.size());
    });
    it.SetMouseReportingMode(InputTranslator::MouseReportingMode::SGR);

    MouseEvent event;
    event.type = MouseEvent::LDown;

    auto expect = [&](const std::string &_expected) {
        it.ProcessMouseEvent(event);
        CHECK(output == _expected);
    };

    SECTION("LB down, (0,0)")
    {
        event.type = MouseEvent::LDown;
        expect("\x1B[<0;1;1M");
    }
    SECTION("LB up, (0,0)")
    {
        event.type = MouseEvent::LUp;
        expect("\x1B[<0;1;1m");
    }
    SECTION("LB drag, (0,0)")
    {
        event.type = MouseEvent::LDrag;
        expect("\x1B[<32;1;1M");
    }
    SECTION("MB down, (0,0)")
    {
        event.type = MouseEvent::MDown;
        expect("\x1B[<1;1;1M");
    }
    SECTION("MB up, (0,0)")
    {
        event.type = MouseEvent::MUp;
        expect("\x1B[<1;1;1m");
    }
    SECTION("MB drag, (0,0)")
    {
        event.type = MouseEvent::MDrag;
        expect("\x1B[<33;1;1M");
    }
    SECTION("RB down, (10,20)")
    {
        event.type = MouseEvent::RDown;
        event.x = 10;
        event.y = 20;
        expect("\x1B[<2;11;21M");
    }
    SECTION("RB up, (0,0)")
    {
        event.type = MouseEvent::RUp;
        expect("\x1B[<2;1;1m");
    }
    SECTION("RB drag, (0,0)")
    {
        event.type = MouseEvent::RDrag;
        expect("\x1B[<34;1;1M");
    }
    SECTION("Limits: -1, -1")
    {
        event.x = -1;
        event.y = -1;
        expect("\x1B[<0;1;1M");
    }
    SECTION("Limits: 2015, 2015")
    {
        event.x = 2015;
        event.y = 2015;
        expect("\x1B[<0;2016;2016M");
    }
    SECTION("Shift")
    {
        event.shift = true;
        expect("\x1B[<4;1;1M");
    }
    SECTION("Alt")
    {
        event.alt = true;
        expect("\x1B[<8;1;1M");
    }
    SECTION("Control")
    {
        event.control = true;
        expect("\x1B[<16;1;1M");
    }
    SECTION("All")
    {
        event.shift = true;
        event.alt = true;
        event.control = true;
        expect("\x1B[<28;1;1M");
    }
    SECTION("Motion")
    {
        event.type = MouseEvent::Motion;
        expect("\x1B[<35;1;1M");
    }
}

TEST_CASE(PREFIX "Pasting")
{
    std::string output;
    InputTranslatorImpl it;
    it.SetOuput([&output](std::span<const std::byte> _bytes) {
        output.append(reinterpret_cast<const char *>(_bytes.data()), _bytes.size());
    });
    SECTION("Default")
    {
        it.ProcessPaste("Hello");
        CHECK(output == "Hello");
    }
    SECTION("Not Bracketed")
    {
        it.SetBracketedPaste(false);
        it.ProcessPaste("Hello");
        CHECK(output == "Hello");
    }
    SECTION("Bracketed")
    {
        it.SetBracketedPaste(true);
        it.ProcessPaste("Hello");
        CHECK(output == "\x1B[200~Hello\x1B[201~");
    }
}
