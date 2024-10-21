// Copyright (C) 2020-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include <ParserImpl.h>
#include "Tests.h"

#pragma clang diagnostic ignored "-Wframe-larger-than="

using namespace nc::term;
using namespace nc::term::input;
#define PREFIX "nc::term::Parser "

static Parser::Bytes to_bytes(const char *_characters)
{
    assert(_characters != nullptr);
    return Parser::Bytes{reinterpret_cast<const std::byte *>(_characters), std::string_view(_characters).size()};
}

static Parser::Bytes to_bytes(const char8_t *_characters)
{
    assert(_characters != nullptr);
    return Parser::Bytes{reinterpret_cast<const std::byte *>(_characters), std::u8string_view{_characters}.size()};
}

static unsigned as_unsigned(const Command &_command)
{
    if( auto ptr = std::get_if<unsigned>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not unsigned");
}

static signed as_signed(const Command &_command)
{
    if( auto ptr = std::get_if<signed>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not signed");
}

static const UTF8Text &as_utf8text(const Command &_command)
{
    if( auto ptr = std::get_if<UTF8Text>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not UTF8Text");
}

static const Title &as_title(const Command &_command)
{
    if( auto ptr = std::get_if<Title>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not Title");
}

static const TitleManipulation &as_title_manipulation(const Command &_command)
{
    if( auto ptr = std::get_if<TitleManipulation>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not TitleManipulation");
}

static const CursorMovement &as_cursor_movement(const Command &_command)
{
    if( auto ptr = std::get_if<CursorMovement>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not CursorMovement");
}

static const DisplayErasure &as_display_erasure(const Command &_command)
{
    if( auto ptr = std::get_if<DisplayErasure>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not DisplayErasure");
}

static const LineErasure &as_line_erasure(const Command &_command)
{
    if( auto ptr = std::get_if<LineErasure>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not LineErasure");
}

static const ModeChange &as_mode_change(const Command &_command)
{
    if( auto ptr = std::get_if<ModeChange>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not ModeChange");
}

static const DeviceReport &as_device_report(const Command &_command)
{
    if( auto ptr = std::get_if<DeviceReport>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not DeviceReport");
}

static const ScrollingRegion &as_scrolling_region(const Command &_command)
{
    if( auto ptr = std::get_if<ScrollingRegion>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not ScrollingRegion");
}

static const TabClear &as_tab_clear(const Command &_command)
{
    if( auto ptr = std::get_if<TabClear>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not TabClear");
}

static const CharacterAttributes &as_character_attributes(const Command &_command)
{
    if( auto ptr = std::get_if<CharacterAttributes>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not CharacterAttributes");
}

static const CharacterSetDesignation &as_character_set_designation(const Command &_command)
{
    if( auto ptr = std::get_if<CharacterSetDesignation>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not CharacterSetDesignation");
}

static const CursorStyle &as_cursor_style(const Command &_command)
{
    if( auto ptr = std::get_if<CursorStyle>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not CursorStyle");
}

TEST_CASE(PREFIX "Parsing empty data returns nothing")
{
    ParserImpl parser;
    CHECK(parser.Parse({}).empty());
}

TEST_CASE(PREFIX "Parsing raw ascii text yields it")
{
    ParserImpl parser;
    SECTION("Single character")
    {
        auto r = parser.Parse(to_bytes("t"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::text);
        CHECK(as_utf8text(r[0]).characters == "t");
    }
    SECTION("Two characters")
    {
        auto r = parser.Parse(to_bytes("qp"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::text);
        CHECK(as_utf8text(r[0]).characters == "qp");
    }
    SECTION("Multiple characters")
    {
        auto r = parser.Parse(to_bytes("Hello, World!"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::text);
        CHECK(as_utf8text(r[0]).characters == "Hello, World!");
    }
    SECTION("Smile")
    {
        auto r = parser.Parse(to_bytes(u8"🤩"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::text);
        CHECK(as_utf8text(r[0]).characters == reinterpret_cast<const char *>(u8"🤩"));
    }
    SECTION("Variable length")
    {
        auto r = parser.Parse(to_bytes(u8"This is какая-то смесь языков 😱!"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::text);
        CHECK(as_utf8text(r[0]).characters == reinterpret_cast<const char *>(u8"This is какая-то смесь языков 😱!"));
    }
}

TEST_CASE(PREFIX "Handles control characters")
{
    ParserImpl parser;
    SECTION("unused")
    {
        std::vector<input::Command> r;
        SECTION("0")
        {
            r = parser.Parse(to_bytes("\x00"));
        }
        SECTION("1")
        {
            r = parser.Parse(to_bytes("\x01"));
        }
        SECTION("2")
        {
            r = parser.Parse(to_bytes("\x02"));
        }
        SECTION("3")
        {
            r = parser.Parse(to_bytes("\x03"));
        }
        SECTION("4")
        {
            r = parser.Parse(to_bytes("\x04"));
        }
        SECTION("5")
        {
            r = parser.Parse(to_bytes("\x05"));
        }
        SECTION("6")
        {
            r = parser.Parse(to_bytes("\x06"));
        }
        SECTION("16")
        {
            r = parser.Parse(to_bytes("\x10"));
        }
        SECTION("17")
        {
            r = parser.Parse(to_bytes("\x11"));
        }
        SECTION("18")
        {
            r = parser.Parse(to_bytes("\x12"));
        }
        SECTION("19")
        {
            r = parser.Parse(to_bytes("\x13"));
        }
        SECTION("20")
        {
            r = parser.Parse(to_bytes("\x14"));
        }
        SECTION("21")
        {
            r = parser.Parse(to_bytes("\x15"));
        }
        SECTION("22")
        {
            r = parser.Parse(to_bytes("\x16"));
        }
        SECTION("23")
        {
            r = parser.Parse(to_bytes("\x17"));
        }
        SECTION("25")
        {
            r = parser.Parse(to_bytes("\x19"));
        }
        SECTION("28")
        {
            r = parser.Parse(to_bytes("\x1C"));
        }
        SECTION("29")
        {
            r = parser.Parse(to_bytes("\x1D"));
        }
        SECTION("30")
        {
            r = parser.Parse(to_bytes("\x1E"));
        }
        SECTION("31")
        {
            r = parser.Parse(to_bytes("\x1F"));
        }
        CHECK(r.empty());
    }
    SECTION("linefeed")
    {
        std::vector<input::Command> r;
        SECTION("10")
        {
            r = parser.Parse(to_bytes("\x0A"));
        }
        SECTION("11")
        {
            r = parser.Parse(to_bytes("\x0B"));
        }
        SECTION("12")
        {
            r = parser.Parse(to_bytes("\x0C"));
        }
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::line_feed);
    }
    SECTION("horizontal tab")
    {
        auto r = parser.Parse(to_bytes("\t"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::horizontal_tab);
        CHECK(as_signed(r[0]) == 1);
    }
    SECTION("carriage return")
    {
        auto r = parser.Parse(to_bytes("\x0D"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::carriage_return);
    }
    SECTION("backspace")
    {
        auto r = parser.Parse(to_bytes("\x08"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::back_space);
    }
    SECTION("bell")
    {
        auto r = parser.Parse(to_bytes("\x07"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::bell);
    }
    SECTION("go into escape mode")
    {
        auto r = parser.Parse(to_bytes("\x1B"));
        REQUIRE(r.empty());
        CHECK(parser.GetEscState() == ParserImpl::EscState::Esc);
        parser.Parse(to_bytes("\x18"));
    }
    SECTION("go to normal mode")
    {
        std::vector<input::Command> r;
        SECTION("")
        {
            r = parser.Parse(to_bytes("\x18"));
        }
        SECTION("")
        {
            r = parser.Parse(to_bytes("\x1A"));
        }
        SECTION("")
        {
            r = parser.Parse(to_bytes("\x1B\x18"));
        }
        SECTION("")
        {
            r = parser.Parse(to_bytes("\x1B\x1A"));
        }
        REQUIRE(r.empty());
    }
    SECTION("select g1")
    {
        auto r = parser.Parse(to_bytes("\x0E"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::select_character_set);
        CHECK(as_unsigned(r[0]) == 1);
    }
    SECTION("select g0")
    {
        auto r = parser.Parse(to_bytes("\x0F"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::select_character_set);
        CHECK(as_unsigned(r[0]) == 0);
    }
    SECTION("ESC E")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "E"));
        REQUIRE(r.size() == 2);
        CHECK(r[0].type == Type::carriage_return);
        CHECK(r[1].type == Type::line_feed);
    }
    SECTION("ESC H")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "H"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_tab);
    }
    SECTION("ESC D")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "D"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::line_feed);
    }
    SECTION("ESC M")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "M"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::reverse_index);
    }
    SECTION("ESC c")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "c"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::reset);
    }
    SECTION("ESC 7")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "7"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::save_state);
    }
    SECTION("ESC 8")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "8"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::restore_state);
    }
    SECTION("ESC # 8")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "#8"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::screen_alignment_test);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "OSC")
{
    ParserImpl parser;
    SECTION("ESC ] 0 ; Hello")
    {
        std::vector<input::Command> r;
        SECTION("")
        {
            r = parser.Parse(to_bytes("\x1B"
                                      "]0;Hello\x07"));
        }
        SECTION("")
        {
            r = parser.Parse(to_bytes("\x1B"
                                      "]0;Hello\x1B\\"));
        }
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::change_title);
        CHECK(as_title(r[0]).kind == Title::IconAndWindow);
        CHECK(as_title(r[0]).title == "Hello");
    }
    SECTION("ESC ] 1 ; Hello")
    {
        std::vector<input::Command> r;
        SECTION("")
        {
            r = parser.Parse(to_bytes("\x1B"
                                      "]1;Hello\x07"));
        }
        SECTION("")
        {
            r = parser.Parse(to_bytes("\x1B"
                                      "]1;Hello\x1B\\"));
        }
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::change_title);
        CHECK(as_title(r[0]).kind == Title::Icon);
        CHECK(as_title(r[0]).title == "Hello");
    }
    SECTION("ESC ] 2 ; Hello")
    {
        std::vector<input::Command> r;
        SECTION("")
        {
            r = parser.Parse(to_bytes("\x1B"
                                      "]2;Hello\x07"));
        }
        SECTION("")
        {
            r = parser.Parse(to_bytes("\x1B"
                                      "]2;Hello\x1B\\"));
        }
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::change_title);
        CHECK(as_title(r[0]).kind == Title::Window);
        CHECK(as_title(r[0]).title == "Hello");
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI A")
{
    ParserImpl parser;
    SECTION("ESC [ A")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[A"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y == -1);
    }
    SECTION("ESC [ 0 A")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[0A"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y == -1);
    }
    SECTION("ESC [ 27 A")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[27A"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y == -27);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI B")
{
    ParserImpl parser;
    SECTION("ESC [ B")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[B"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y == 1);
    }
    SECTION("ESC [ 0 B")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[0B"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y == 1);
    }
    SECTION("ESC [ 45 A")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[45B"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y == 45);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI C")
{
    ParserImpl parser;
    SECTION("ESC [ C")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[C"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == 1);
        CHECK(as_cursor_movement(r[0]).y == 0);
    }
    SECTION("ESC [ 0 C")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[0C"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == 1);
        CHECK(as_cursor_movement(r[0]).y == 0);
    }
    SECTION("ESC [ 42 C")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[42C"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == 42);
        CHECK(as_cursor_movement(r[0]).y == 0);
    }
    SECTION("ESC [ 2 BS C")
    {
        auto r = parser.Parse(to_bytes("\x1B[2\x08"
                                       "C"));
        REQUIRE(r.size() == 2);
        CHECK(r[0].type == Type::back_space);
        CHECK(r[1].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[1]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[1]).x == 2);
        CHECK(as_cursor_movement(r[1]).y == 0);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI D")
{
    ParserImpl parser;
    SECTION("ESC [ D")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[D"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == -1);
        CHECK(as_cursor_movement(r[0]).y == 0);
    }
    SECTION("ESC [ 0 D")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[0D"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == -1);
        CHECK(as_cursor_movement(r[0]).y == 0);
    }
    SECTION("ESC [ 32 D")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[32D"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == -32);
        CHECK(as_cursor_movement(r[0]).y == 0);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI E")
{
    ParserImpl parser;
    SECTION("ESC [ E")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[E"));
        REQUIRE(r.size() == 2);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == std::nullopt);
        CHECK(as_cursor_movement(r[0]).y == 1);
        CHECK(r[1].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[1]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[1]).x == 0);
        CHECK(as_cursor_movement(r[1]).y == std::nullopt);
    }
    SECTION("ESC [ 7 E")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[7E"));
        REQUIRE(r.size() == 2);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == std::nullopt);
        CHECK(as_cursor_movement(r[0]).y == 7);
        CHECK(r[1].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[1]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[1]).x == 0);
        CHECK(as_cursor_movement(r[1]).y == std::nullopt);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI F")
{
    ParserImpl parser;
    SECTION("ESC [ F")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[F"));
        REQUIRE(r.size() == 2);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == std::nullopt);
        CHECK(as_cursor_movement(r[0]).y == -1);
        CHECK(r[1].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[1]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[1]).x == 0);
        CHECK(as_cursor_movement(r[1]).y == std::nullopt);
    }
    SECTION("ESC [ 8 F")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[8F"));
        REQUIRE(r.size() == 2);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Relative);
        CHECK(as_cursor_movement(r[0]).x == std::nullopt);
        CHECK(as_cursor_movement(r[0]).y == -8);
        CHECK(r[1].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[1]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[1]).x == 0);
        CHECK(as_cursor_movement(r[1]).y == std::nullopt);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI G")
{
    ParserImpl parser;
    SECTION("ESC [ G")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[G"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y.has_value() == false);
    }
    SECTION("ESC [ 71 G")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[71G"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[0]).x == 70);
        CHECK(as_cursor_movement(r[0]).y.has_value() == false);
    }
    SECTION("ESC [ 0 G")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[0G"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y.has_value() == false);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI H")
{
    ParserImpl parser;
    SECTION("ESC [ H")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[H"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y == 0);
    }
    SECTION("ESC [ 5 ; 10 H")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[5;10H"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[0]).x == 9);
        CHECK(as_cursor_movement(r[0]).y == 4);
    }
    SECTION("ESC [ 0 ; 0 H")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[0;0H"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y == 0);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI I")
{
    ParserImpl parser;
    SECTION("ESC [ I")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[I"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::horizontal_tab);
        CHECK(as_signed(r[0]) == 1);
    }
    SECTION("ESC [ 123 I")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[123I"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::horizontal_tab);
        CHECK(as_signed(r[0]) == 123);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI J")
{
    ParserImpl parser;
    using Area = DisplayErasure::Area;
    SECTION("ESC [ J")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[J"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::erase_in_display);
        CHECK(as_display_erasure(r[0]).what_to_erase == Area::FromCursorToDisplayEnd);
    }
    SECTION("ESC [ 0 J")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[0J"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::erase_in_display);
        CHECK(as_display_erasure(r[0]).what_to_erase == Area::FromCursorToDisplayEnd);
    }
    SECTION("ESC [ 1 J")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[1J"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::erase_in_display);
        CHECK(as_display_erasure(r[0]).what_to_erase == Area::FromDisplayStartToCursor);
    }
    SECTION("ESC [ 2 J")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[2J"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::erase_in_display);
        CHECK(as_display_erasure(r[0]).what_to_erase == Area::WholeDisplay);
    }
    SECTION("ESC [ 3 J")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[3J"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::erase_in_display);
        CHECK(as_display_erasure(r[0]).what_to_erase == Area::WholeDisplayWithScrollback);
    }
    SECTION("ESC [ 4 J")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[4J"));
        REQUIRE(r.empty());
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI K")
{
    ParserImpl parser;
    using Area = LineErasure::Area;
    SECTION("ESC [ K")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[K"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::erase_in_line);
        CHECK(as_line_erasure(r[0]).what_to_erase == Area::FromCursorToLineEnd);
    }
    SECTION("ESC [ 0 K")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[0K"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::erase_in_line);
        CHECK(as_line_erasure(r[0]).what_to_erase == Area::FromCursorToLineEnd);
    }
    SECTION("ESC [ 1 K")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[1K"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::erase_in_line);
        CHECK(as_line_erasure(r[0]).what_to_erase == Area::FromLineStartToCursor);
    }
    SECTION("ESC [ 2 K")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[2K"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::erase_in_line);
        CHECK(as_line_erasure(r[0]).what_to_erase == Area::WholeLine);
    }
    SECTION("ESC [ 3 K")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[3K"));
        REQUIRE(r.empty());
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI L")
{
    ParserImpl parser;
    SECTION("ESC [ L")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[L"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::insert_lines);
        CHECK(as_unsigned(r[0]) == 1);
    }
    SECTION("ESC [ 12 L")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[12L"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::insert_lines);
        CHECK(as_unsigned(r[0]) == 12);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI M")
{
    ParserImpl parser;
    SECTION("ESC [ M")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[M"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::delete_lines);
        CHECK(as_unsigned(r[0]) == 1);
    }
    SECTION("ESC [ 23 M")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[23M"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::delete_lines);
        CHECK(as_unsigned(r[0]) == 23);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI P")
{
    ParserImpl parser;
    SECTION("ESC [ P")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[P"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::delete_characters);
        CHECK(as_unsigned(r[0]) == 1);
    }
    SECTION("ESC [ 34 P")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[34P"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::delete_characters);
        CHECK(as_unsigned(r[0]) == 34);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI S")
{
    ParserImpl parser;
    SECTION("ESC [ S")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[S"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::scroll_lines);
        CHECK(as_signed(r[0]) == 1);
    }
    SECTION("ESC [ 45 S")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[45S"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::scroll_lines);
        CHECK(as_signed(r[0]) == 45);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI T")
{
    ParserImpl parser;
    SECTION("ESC [ T")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[T"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::scroll_lines);
        CHECK(as_signed(r[0]) == -1);
    }
    SECTION("ESC [ 56 T")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[56T"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::scroll_lines);
        CHECK(as_signed(r[0]) == -56);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI X")
{
    ParserImpl parser;
    SECTION("ESC [ X")
    {
        auto r = parser.Parse(to_bytes("\x1B[X"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::erase_characters);
        CHECK(as_unsigned(r[0]) == 1);
    }
    SECTION("ESC [ 0 X")
    {
        auto r = parser.Parse(to_bytes("\x1B[0X"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::erase_characters);
        CHECK(as_unsigned(r[0]) == 1);
    }
    SECTION("ESC [ 67 X")
    {
        auto r = parser.Parse(to_bytes("\x1B[67X"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::erase_characters);
        CHECK(as_unsigned(r[0]) == 67);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI Z")
{
    ParserImpl parser;
    SECTION("ESC [ Z")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[Z"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::horizontal_tab);
        CHECK(as_signed(r[0]) == -1);
    }
    SECTION("ESC [ 1234 Z")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[1234Z"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::horizontal_tab);
        CHECK(as_signed(r[0]) == -1234);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI a")
{
    ParserImpl parser;
    SECTION("ESC [ a")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[a"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Relative);
        CHECK(as_cursor_movement(r[0]).x == 1);
        CHECK(as_cursor_movement(r[0]).y == std::nullopt);
    }
    SECTION("ESC [ 7 a")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[7a"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Relative);
        CHECK(as_cursor_movement(r[0]).x == 7);
        CHECK(as_cursor_movement(r[0]).y == std::nullopt);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI b")
{
    ParserImpl parser;
    SECTION("ESC [ b")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[b"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::repeat_last_character);
        CHECK(as_unsigned(r[0]) == 1);
    }
    SECTION("ESC [ 7 b")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[7b"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::repeat_last_character);
        CHECK(as_unsigned(r[0]) == 7);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI c")
{
    ParserImpl parser;
    SECTION("ESC [ c")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[c"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::report);
        CHECK(as_device_report(r[0]).mode == DeviceReport::Kind::TerminalId);
    }
    SECTION("ESC [ 0 c")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[0c"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::report);
        CHECK(as_device_report(r[0]).mode == DeviceReport::Kind::TerminalId);
    }
    SECTION("ESC [ 1 c")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[1c"));
        REQUIRE(r.empty());
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI d")
{
    ParserImpl parser;
    SECTION("ESC [ d")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[d"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Absolute);
        CHECK(as_cursor_movement(r[0]).x == std::nullopt);
        CHECK(as_cursor_movement(r[0]).y == 0);
    }
    SECTION("ESC [ 5 d")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[5d"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Absolute);
        CHECK(as_cursor_movement(r[0]).x == std::nullopt);
        CHECK(as_cursor_movement(r[0]).y == 4);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI e")
{
    ParserImpl parser;
    SECTION("ESC [ e")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[e"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Relative);
        CHECK(as_cursor_movement(r[0]).x == std::nullopt);
        CHECK(as_cursor_movement(r[0]).y == 1);
    }
    SECTION("ESC [ 5 e")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[5e"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Relative);
        CHECK(as_cursor_movement(r[0]).x == std::nullopt);
        CHECK(as_cursor_movement(r[0]).y == 5);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI f")
{
    ParserImpl parser;
    SECTION("ESC [ f")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[f"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y == 0);
    }
    SECTION("ESC [ 5 ; 10 f")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[5;10f"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[0]).x == 9);
        CHECK(as_cursor_movement(r[0]).y == 4);
    }
    SECTION("ESC [ 0 ; 0 f")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[0;0f"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Absolute);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y == 0);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI g")
{
    ParserImpl parser;
    SECTION("ESC [ g")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[g"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::clear_tab);
        CHECK(as_tab_clear(r[0]).mode == input::TabClear::CurrentColumn);
    }
    SECTION("ESC [ 0 g")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[0g"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::clear_tab);
        CHECK(as_tab_clear(r[0]).mode == input::TabClear::CurrentColumn);
    }
    SECTION("ESC [ 1 g")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[1g"));
        CHECK(r.empty());
    }
    SECTION("ESC [ 2 g")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[2g"));
        CHECK(r.empty());
    }
    SECTION("ESC [ 3 g")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[3g"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::clear_tab);
        CHECK(as_tab_clear(r[0]).mode == input::TabClear::All);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI hl")
{
    ParserImpl parser;
    using Kind = ModeChange::Kind;
    auto verify = [&](const char *_cmd, Kind _kind, bool _status) {
        auto r = parser.Parse(to_bytes(_cmd));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::change_mode);
        CHECK(as_mode_change(r[0]).mode == _kind);
        CHECK(as_mode_change(r[0]).status == _status);
    };
    SECTION("ESC [ 4 h")
    {
        verify("\x1B"
               "[4h",
               Kind::Insert,
               true);
    }
    SECTION("ESC [ 4 l")
    {
        verify("\x1B"
               "[4l",
               Kind::Insert,
               false);
    }
    SECTION("ESC [ 20 h")
    {
        verify("\x1B"
               "[20h",
               Kind::NewLine,
               true);
    }
    SECTION("ESC [ 20 l")
    {
        verify("\x1B"
               "[20l",
               Kind::NewLine,
               false);
    }
    SECTION("ESC [ ? 1 h")
    {
        verify("\x1B"
               "[?1h",
               Kind::ApplicationCursorKeys,
               true);
    }
    SECTION("ESC [ ? 1 l")
    {
        verify("\x1B"
               "[?1l",
               Kind::ApplicationCursorKeys,
               false);
    }
    SECTION("ESC [ ? 3 h")
    {
        verify("\x1B"
               "[?3h",
               Kind::Column132,
               true);
    }
    SECTION("ESC [ ? 3 l")
    {
        verify("\x1B"
               "[?3l",
               Kind::Column132,
               false);
    }
    SECTION("ESC [ ? 4 h")
    {
        verify("\x1B"
               "[?4h",
               Kind::SmoothScroll,
               true);
    }
    SECTION("ESC [ ? 4 l")
    {
        verify("\x1B"
               "[?4l",
               Kind::SmoothScroll,
               false);
    }
    SECTION("ESC [ ? 5 h")
    {
        verify("\x1B"
               "[?5h",
               Kind::ReverseVideo,
               true);
    }
    SECTION("ESC [ ? 5 l")
    {
        verify("\x1B"
               "[?5l",
               Kind::ReverseVideo,
               false);
    }
    SECTION("ESC [ ? 6 h")
    {
        verify("\x1B"
               "[?6h",
               Kind::Origin,
               true);
    }
    SECTION("ESC [ ? 6 l")
    {
        verify("\x1B"
               "[?6l",
               Kind::Origin,
               false);
    }
    SECTION("ESC [ ? 7 h")
    {
        verify("\x1B"
               "[?7h",
               Kind::AutoWrap,
               true);
    }
    SECTION("ESC [ ? 7 l")
    {
        verify("\x1B"
               "[?7l",
               Kind::AutoWrap,
               false);
    }
    SECTION("ESC [ ? 12 h")
    {
        verify("\x1B"
               "[?12h",
               Kind::BlinkingCursor,
               true);
    }
    SECTION("ESC [ ? 12 l")
    {
        verify("\x1B"
               "[?12l",
               Kind::BlinkingCursor,
               false);
    }
    SECTION("ESC [ ? 8 h")
    {
        verify("\x1B"
               "[?8h",
               Kind::AutoRepeatKeys,
               true);
    }
    SECTION("ESC [ ? 8 l")
    {
        verify("\x1B"
               "[?8l",
               Kind::AutoRepeatKeys,
               false);
    }
    SECTION("ESC [ ? 9 h")
    {
        verify("\x1B"
               "[?9h",
               Kind::SendMouseXYOnPress,
               true);
    }
    SECTION("ESC [ ? 9 l")
    {
        verify("\x1B"
               "[?9l",
               Kind::SendMouseXYOnPress,
               false);
    }
    SECTION("ESC [ ? 25 h")
    {
        verify("\x1B"
               "[?25h",
               Kind::ShowCursor,
               true);
    }
    SECTION("ESC [ ? 25 l")
    {
        verify("\x1B"
               "[?25l",
               Kind::ShowCursor,
               false);
    }
    SECTION("ESC [ ? 47 h")
    {
        verify("\x1B"
               "[?47h",
               Kind::AlternateScreenBuffer,
               true);
    }
    SECTION("ESC [ ? 47 l")
    {
        verify("\x1B"
               "[?47l",
               Kind::AlternateScreenBuffer,
               false);
    }
    SECTION("ESC [ ? 1000 h")
    {
        verify("\x1B"
               "[?1000h",
               Kind::SendMouseXYOnPressAndRelease,
               true);
    }
    SECTION("ESC [ ? 1000 l")
    {
        verify("\x1B"
               "[?1000l",
               Kind::SendMouseXYOnPressAndRelease,
               false);
    }
    SECTION("ESC [ ? 1002 h")
    {
        verify("\x1B"
               "[?1002h",
               Kind::SendMouseXYOnPressDragAndRelease,
               true);
    }
    SECTION("ESC [ ? 1002 l")
    {
        verify("\x1B"
               "[?1002l",
               Kind::SendMouseXYOnPressDragAndRelease,
               false);
    }
    SECTION("ESC [ ? 1003 h")
    {
        verify("\x1B"
               "[?1003h",
               Kind::SendMouseXYAnyEvent,
               true);
    }
    SECTION("ESC [ ? 1003 l")
    {
        verify("\x1B"
               "[?1003l",
               Kind::SendMouseXYAnyEvent,
               false);
    }
    SECTION("ESC [ ? 1005 h")
    {
        verify("\x1B"
               "[?1005h",
               Kind::SendMouseReportUFT8,
               true);
    }
    SECTION("ESC [ ? 1005 l")
    {
        verify("\x1B"
               "[?1005l",
               Kind::SendMouseReportUFT8,
               false);
    }
    SECTION("ESC [ ? 1006 h")
    {
        verify("\x1B"
               "[?1006h",
               Kind::SendMouseReportSGR,
               true);
    }
    SECTION("ESC [ ? 1006 l")
    {
        verify("\x1B"
               "[?1006l",
               Kind::SendMouseReportSGR,
               false);
    }
    SECTION("ESC [ ? 1049 h")
    {
        verify("\x1B"
               "[?1049h",
               Kind::AlternateScreenBuffer1049,
               true);
    }
    SECTION("ESC [ ? 1049 l")
    {
        verify("\x1B"
               "[?1049l",
               Kind::AlternateScreenBuffer1049,
               false);
    }
    SECTION("ESC [ ? 2004 h")
    {
        verify("\x1B"
               "[?2004h",
               Kind::BracketedPaste,
               true);
    }
    SECTION("ESC [ ? 2004 l")
    {
        verify("\x1B"
               "[?2004l",
               Kind::BracketedPaste,
               false);
    }
    SECTION("ESC [ h")
    {
        REQUIRE(parser
                    .Parse(to_bytes("\x1B"
                                    "[h"))
                    .empty());
    }
    SECTION("ESC [ l")
    {
        REQUIRE(parser
                    .Parse(to_bytes("\x1B"
                                    "[l"))
                    .empty());
    }
    SECTION("ESC [ ? 1006 ; 1000 h")
    {
        auto r = parser.Parse(to_bytes("\x1B[?1006;1000h"));
        REQUIRE(r.size() == 2);
        CHECK(r[0].type == Type::change_mode);
        CHECK(as_mode_change(r[0]).mode == Kind::SendMouseReportSGR);
        CHECK(as_mode_change(r[0]).status == true);
        CHECK(r[1].type == Type::change_mode);
        CHECK(as_mode_change(r[1]).mode == Kind::SendMouseXYOnPressAndRelease);
        CHECK(as_mode_change(r[1]).status == true);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI m")
{
    ParserImpl parser;
    using CA = CharacterAttributes;
    auto ignores = [&](const char *_cmd) { CHECK(parser.Parse(to_bytes(_cmd)).empty()); };
    auto verify = [&](const char *_cmd, CA _ca) {
        auto r = parser.Parse(to_bytes(_cmd));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_character_attributes);
        CHECK(as_character_attributes(r[0]) == _ca);
    };
    SECTION("ESC [ m")
    {
        verify("\x1B[m", CA{.mode = CA::Normal});
    }
    SECTION("ESC [ 0 m")
    {
        verify("\x1B[0m", CA{.mode = CA::Normal});
    }
    SECTION("ESC [ 1 m")
    {
        verify("\x1B[1m", CA{.mode = CA::Bold});
    }
    SECTION("ESC [ ; 1 m")
    {
        auto r = parser.Parse(to_bytes("\x1B[;1m"));
        REQUIRE(r.size() == 2);
        CHECK(r[0].type == Type::set_character_attributes);
        CHECK(as_character_attributes(r[0]).mode == CA::Normal);
        CHECK(r[1].type == Type::set_character_attributes);
        CHECK(as_character_attributes(r[1]).mode == CA::Bold);
    }
    SECTION("ESC [ 0 ; 1 m")
    {
        auto r = parser.Parse(to_bytes("\x1B[0;1m"));
        REQUIRE(r.size() == 2);
        CHECK(r[0].type == Type::set_character_attributes);
        CHECK(as_character_attributes(r[0]).mode == CA::Normal);
        CHECK(r[1].type == Type::set_character_attributes);
        CHECK(as_character_attributes(r[1]).mode == CA::Bold);
    }
    SECTION("ESC [ 2 m")
    {
        verify("\x1B[2m", CA{.mode = CA::Faint});
    }
    SECTION("ESC [ 3 m")
    {
        verify("\x1B[3m", CA{.mode = CA::Italicized});
    }
    SECTION("ESC [ 4 m")
    {
        verify("\x1B[4m", CA{.mode = CA::Underlined});
    }
    SECTION("ESC [ 5 m")
    {
        verify("\x1B[5m", CA{.mode = CA::Blink});
    }
    SECTION("ESC [ 7 m")
    {
        verify("\x1B[7m", CA{.mode = CA::Inverse});
    }
    SECTION("ESC [ 8 m")
    {
        verify("\x1B[8m", CA{.mode = CA::Invisible});
    }
    SECTION("ESC [ 9 m")
    {
        verify("\x1B[9m", CA{.mode = CA::Crossed});
    }
    SECTION("ESC [ 21 m")
    {
        verify("\x1B[21m", CA{.mode = CA::DoublyUnderlined});
    }
    SECTION("ESC [ 22 m")
    {
        verify("\x1B[22m", CA{.mode = CA::NotBoldNotFaint});
    }
    SECTION("ESC [ 23 m")
    {
        verify("\x1B[23m", CA{.mode = CA::NotItalicized});
    }
    SECTION("ESC [ 24 m")
    {
        verify("\x1B[24m", CA{.mode = CA::NotUnderlined});
    }
    SECTION("ESC [ 25 m")
    {
        verify("\x1B[25m", CA{.mode = CA::NotBlink});
    }
    SECTION("ESC [ 27 m")
    {
        verify("\x1B[27m", CA{.mode = CA::NotInverse});
    }
    SECTION("ESC [ 28 m")
    {
        verify("\x1B[28m", CA{.mode = CA::NotInvisible});
    }
    SECTION("ESC [ 29 m")
    {
        verify("\x1B[29m", CA{.mode = CA::NotCrossed});
    }
    SECTION("ESC [ 30 m")
    {
        verify("\x1B[30m", CA{.mode = CA::ForegroundColor, .color = Color::Black});
    }
    SECTION("ESC [ 31 m")
    {
        verify("\x1B[31m", CA{.mode = CA::ForegroundColor, .color = Color::Red});
    }
    SECTION("ESC [ 32 m")
    {
        verify("\x1B[32m", CA{.mode = CA::ForegroundColor, .color = Color::Green});
    }
    SECTION("ESC [ 33 m")
    {
        verify("\x1B[33m", CA{.mode = CA::ForegroundColor, .color = Color::Yellow});
    }
    SECTION("ESC [ 34 m")
    {
        verify("\x1B[34m", CA{.mode = CA::ForegroundColor, .color = Color::Blue});
    }
    SECTION("ESC [ 35 m")
    {
        verify("\x1B[35m", CA{.mode = CA::ForegroundColor, .color = Color::Magenta});
    }
    SECTION("ESC [ 36 m")
    {
        verify("\x1B[36m", CA{.mode = CA::ForegroundColor, .color = Color::Cyan});
    }
    SECTION("ESC [ 37 m")
    {
        verify("\x1B[37m", CA{.mode = CA::ForegroundColor, .color = Color::White});
    }
    SECTION("ESC [ 38 m")
    {
        ignores("\x1B[38m");
        ignores("\x1B[38;5m");
        ignores("\x1B[38;42m");
        ignores("\x1B[38;5;256m");
        ignores("\x1B[38;5;500m");
        verify("\x1B[38;5;0m", CA{.mode = CA::ForegroundColor, .color = Color::Black});
        verify("\x1B[38;5;15m", CA{.mode = CA::ForegroundColor, .color = Color::BrightWhite});
        verify("\x1B[38;5;16m", CA{.mode = CA::ForegroundColor, .color = Color{16}});
        verify("\x1B[38;5;100m", CA{.mode = CA::ForegroundColor, .color = Color{100}});
        verify("\x1B[38;5;255m", CA{.mode = CA::ForegroundColor, .color = Color{255}});
        ignores("\x1B[38;2m");
        ignores("\x1B[38;2;0m");
        ignores("\x1B[38;2;0;0m");
        ignores("\x1B[38;2;256;256;256m");
        verify("\x1B[38;2;0;0;0m", CA{.mode = CA::ForegroundColor, .color = Color{232}});
        verify("\x1B[38;2;255;255;255m", CA{.mode = CA::ForegroundColor, .color = Color{255}});
    }
    SECTION("ESC [ 39 m")
    {
        verify("\x1B[39m", CA{.mode = CA::ForegroundDefault});
    }
    SECTION("ESC [ 40 m")
    {
        verify("\x1B[40m", CA{.mode = CA::BackgroundColor, .color = Color::Black});
    }
    SECTION("ESC [ 41 m")
    {
        verify("\x1B[41m", CA{.mode = CA::BackgroundColor, .color = Color::Red});
    }
    SECTION("ESC [ 42 m")
    {
        verify("\x1B[42m", CA{.mode = CA::BackgroundColor, .color = Color::Green});
    }
    SECTION("ESC [ 43 m")
    {
        verify("\x1B[43m", CA{.mode = CA::BackgroundColor, .color = Color::Yellow});
    }
    SECTION("ESC [ 44 m")
    {
        verify("\x1B[44m", CA{.mode = CA::BackgroundColor, .color = Color::Blue});
    }
    SECTION("ESC [ 45 m")
    {
        verify("\x1B[45m", CA{.mode = CA::BackgroundColor, .color = Color::Magenta});
    }
    SECTION("ESC [ 46 m")
    {
        verify("\x1B[46m", CA{.mode = CA::BackgroundColor, .color = Color::Cyan});
    }
    SECTION("ESC [ 47 m")
    {
        verify("\x1B[47m", CA{.mode = CA::BackgroundColor, .color = Color::White});
    }
    SECTION("ESC [ 48 m")
    {
        ignores("\x1B[48m");
        ignores("\x1B[48;5m");
        ignores("\x1B[48;42m");
        ignores("\x1B[48;5;256m");
        ignores("\x1B[48;5;500m");
        verify("\x1B[48;5;0m", CA{.mode = CA::BackgroundColor, .color = Color::Black});
        verify("\x1B[48;5;15m", CA{.mode = CA::BackgroundColor, .color = Color::BrightWhite});
        verify("\x1B[48;5;16m", CA{.mode = CA::BackgroundColor, .color = Color{16}});
        verify("\x1B[48;5;100m", CA{.mode = CA::BackgroundColor, .color = Color{100}});
        verify("\x1B[48;5;255m", CA{.mode = CA::BackgroundColor, .color = Color{255}});
        ignores("\x1B[48;2m");
        ignores("\x1B[48;2;0m");
        ignores("\x1B[48;2;0;0m");
        ignores("\x1B[48;2;256;256;256m");
        verify("\x1B[48;2;0;0;0m", CA{.mode = CA::BackgroundColor, .color = Color{232}});
        verify("\x1B[48;2;255;255;255m", CA{.mode = CA::BackgroundColor, .color = Color{255}});
    }
    SECTION("ESC [ 49 m")
    {
        verify("\x1B[49m", CA{.mode = CA::BackgroundDefault});
    }
    SECTION("ESC [ 90 m")
    {
        verify("\x1B[90m", CA{.mode = CA::ForegroundColor, .color = Color::BrightBlack});
    }
    SECTION("ESC [ 91 m")
    {
        verify("\x1B[91m", CA{.mode = CA::ForegroundColor, .color = Color::BrightRed});
    }
    SECTION("ESC [ 92 m")
    {
        verify("\x1B[92m", CA{.mode = CA::ForegroundColor, .color = Color::BrightGreen});
    }
    SECTION("ESC [ 93 m")
    {
        verify("\x1B[93m", CA{.mode = CA::ForegroundColor, .color = Color::BrightYellow});
    }
    SECTION("ESC [ 94 m")
    {
        verify("\x1B[94m", CA{.mode = CA::ForegroundColor, .color = Color::BrightBlue});
    }
    SECTION("ESC [ 95 m")
    {
        verify("\x1B[95m", CA{.mode = CA::ForegroundColor, .color = Color::BrightMagenta});
    }
    SECTION("ESC [ 96 m")
    {
        verify("\x1B[96m", CA{.mode = CA::ForegroundColor, .color = Color::BrightCyan});
    }
    SECTION("ESC [ 97 m")
    {
        verify("\x1B[97m", CA{.mode = CA::ForegroundColor, .color = Color::BrightWhite});
    }
    SECTION("ESC [ 100 m")
    {
        verify("\x1B[100m", CA{.mode = CA::BackgroundColor, .color = Color::BrightBlack});
    }
    SECTION("ESC [ 101 m")
    {
        verify("\x1B[101m", CA{.mode = CA::BackgroundColor, .color = Color::BrightRed});
    }
    SECTION("ESC [ 102 m")
    {
        verify("\x1B[102m", CA{.mode = CA::BackgroundColor, .color = Color::BrightGreen});
    }
    SECTION("ESC [ 103 m")
    {
        verify("\x1B[103m", CA{.mode = CA::BackgroundColor, .color = Color::BrightYellow});
    }
    SECTION("ESC [ 104 m")
    {
        verify("\x1B[104m", CA{.mode = CA::BackgroundColor, .color = Color::BrightBlue});
    }
    SECTION("ESC [ 105 m")
    {
        verify("\x1B[105m", CA{.mode = CA::BackgroundColor, .color = Color::BrightMagenta});
    }
    SECTION("ESC [ 106 m")
    {
        verify("\x1B[106m", CA{.mode = CA::BackgroundColor, .color = Color::BrightCyan});
    }
    SECTION("ESC [ 107 m")
    {
        verify("\x1B[107m", CA{.mode = CA::BackgroundColor, .color = Color::BrightWhite});
    }
    SECTION("Combination")
    {
        auto r = parser.Parse(to_bytes("\x1B[01;04;38;05;196;48;05;232m"));
        REQUIRE(r.size() == 4);
        CHECK(as_character_attributes(r[0]) == CA{.mode = CA::Bold});
        CHECK(as_character_attributes(r[1]) == CA{.mode = CA::Underlined});
        CHECK(as_character_attributes(r[2]) == CA{.mode = CA::ForegroundColor, .color = Color{196}});
        CHECK(as_character_attributes(r[3]) == CA{.mode = CA::BackgroundColor, .color = Color{232}});
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI n")
{
    ParserImpl parser;
    SECTION("ESC [ 5 n")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[5n"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::report);
        CHECK(as_device_report(r[0]).mode == DeviceReport::DeviceStatus);
    }
    SECTION("ESC [ 6 n")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[6n"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::report);
        CHECK(as_device_report(r[0]).mode == DeviceReport::CursorPosition);
    }
    SECTION("ESC [ n")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[n"));
        REQUIRE(r.empty());
    }
    SECTION("ESC [ 0 n")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[0n"));
        REQUIRE(r.empty());
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI Ps SP q")
{
    ParserImpl parser;
    SECTION("ESC SP q")
    {
        auto r = parser.Parse(to_bytes("\x1B[ q"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_cursor_style);
        CHECK(as_cursor_style(r[0]).style == std::nullopt);
    }
    SECTION("ESC 0 SP q")
    {
        auto r = parser.Parse(to_bytes("\x1B[0 q"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_cursor_style);
        CHECK(as_cursor_style(r[0]).style == std::nullopt);
    }
    SECTION("ESC 1 SP q")
    {
        auto r = parser.Parse(to_bytes("\x1B[1 q"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_cursor_style);
        CHECK(as_cursor_style(r[0]).style == CursorMode::BlinkingBlock);
    }
    SECTION("ESC 2 SP q")
    {
        auto r = parser.Parse(to_bytes("\x1B[2 q"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_cursor_style);
        CHECK(as_cursor_style(r[0]).style == CursorMode::SteadyBlock);
    }
    SECTION("ESC 3 SP q")
    {
        auto r = parser.Parse(to_bytes("\x1B[3 q"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_cursor_style);
        CHECK(as_cursor_style(r[0]).style == CursorMode::BlinkingUnderline);
    }
    SECTION("ESC 4 SP q")
    {
        auto r = parser.Parse(to_bytes("\x1B[4 q"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_cursor_style);
        CHECK(as_cursor_style(r[0]).style == CursorMode::SteadyUnderline);
    }
    SECTION("ESC 5 SP q")
    {
        auto r = parser.Parse(to_bytes("\x1B[5 q"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_cursor_style);
        CHECK(as_cursor_style(r[0]).style == CursorMode::BlinkingBar);
    }
    SECTION("ESC 6 SP q")
    {
        auto r = parser.Parse(to_bytes("\x1B[6 q"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_cursor_style);
        CHECK(as_cursor_style(r[0]).style == CursorMode::SteadyBar);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI r")
{
    ParserImpl parser;
    SECTION("ESC [ r")
    {
        auto r = parser.Parse(to_bytes("\x1B[r"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_scrolling_region);
        CHECK(as_scrolling_region(r[0]).range == std::nullopt);
    }
    SECTION("ESC [ 0 ; 0 r")
    {
        auto r = parser.Parse(to_bytes("\x1B[0;0r"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_scrolling_region);
        CHECK(as_scrolling_region(r[0]).range == std::nullopt);
    }
    SECTION("ESC [ 5 ; 15 r")
    {
        auto r = parser.Parse(to_bytes("\x1B[5;15r"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::set_scrolling_region);
        REQUIRE(as_scrolling_region(r[0]).range != std::nullopt);
        CHECK(as_scrolling_region(r[0]).range->top == 4);
        CHECK(as_scrolling_region(r[0]).range->bottom == 15);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI t")
{
    ParserImpl parser;
    SECTION("ESC [ 22 ; 0 t")
    {
        auto r = parser.Parse(to_bytes("\x1B[22;0t"));
        CHECK(r[0].type == Type::manipulate_title);
        CHECK(as_title_manipulation(r[0]).target == TitleManipulation::Both);
        CHECK(as_title_manipulation(r[0]).operation == TitleManipulation::Save);
    }
    SECTION("ESC [ 22 ; 1 t")
    {
        auto r = parser.Parse(to_bytes("\x1B[22;1t"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::manipulate_title);
        CHECK(as_title_manipulation(r[0]).target == TitleManipulation::Icon);
        CHECK(as_title_manipulation(r[0]).operation == TitleManipulation::Save);
    }
    SECTION("ESC [ 22 ; 2 t")
    {
        auto r = parser.Parse(to_bytes("\x1B[22;2t"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::manipulate_title);
        CHECK(as_title_manipulation(r[0]).target == TitleManipulation::Window);
        CHECK(as_title_manipulation(r[0]).operation == TitleManipulation::Save);
    }
    SECTION("ESC [ 23 ; 0 t")
    {
        auto r = parser.Parse(to_bytes("\x1B[23;0t"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::manipulate_title);
        CHECK(as_title_manipulation(r[0]).target == TitleManipulation::Both);
        CHECK(as_title_manipulation(r[0]).operation == TitleManipulation::Restore);
    }
    SECTION("ESC [ 23 ; 1 t")
    {
        auto r = parser.Parse(to_bytes("\x1B[23;1t"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::manipulate_title);
        CHECK(as_title_manipulation(r[0]).target == TitleManipulation::Icon);
        CHECK(as_title_manipulation(r[0]).operation == TitleManipulation::Restore);
    }
    SECTION("ESC [ 23 ; 2 t")
    {
        auto r = parser.Parse(to_bytes("\x1B[23;2t"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::manipulate_title);
        CHECK(as_title_manipulation(r[0]).target == TitleManipulation::Window);
        CHECK(as_title_manipulation(r[0]).operation == TitleManipulation::Restore);
    }
    SECTION("Bogus input")
    {
        REQUIRE(parser.Parse(to_bytes("\x1B[t")).empty());
        REQUIRE(parser.Parse(to_bytes("\x1B[23;3t")).empty());
        REQUIRE(parser.Parse(to_bytes("\x1B[100t")).empty());
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI `")
{
    ParserImpl parser;
    SECTION("ESC [ `")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[`"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Absolute);
        CHECK(as_cursor_movement(r[0]).x == 0);
        CHECK(as_cursor_movement(r[0]).y == std::nullopt);
    }
    SECTION("ESC [ 7 `")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[7`"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::move_cursor);
        CHECK(as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Absolute);
        CHECK(as_cursor_movement(r[0]).x == 6);
        CHECK(as_cursor_movement(r[0]).y == std::nullopt);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSI @")
{
    ParserImpl parser;
    SECTION("ESC [ @")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[@"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::insert_characters);
        CHECK(as_unsigned(r[0]) == 1);
    }
    SECTION("ESC [ 42 @")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "[42@"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::insert_characters);
        CHECK(as_unsigned(r[0]) == 42);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "Character set designation")
{
    ParserImpl parser;
    using CSD = CharacterSetDesignation;
    SECTION("ESC ( 0")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "(0"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::designate_character_set);
        CHECK(as_character_set_designation(r[0]).target == 0);
        CHECK(as_character_set_designation(r[0]).set == CSD::DECSpecialGraphics);
    }
    SECTION("ESC ( A")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "(A"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::designate_character_set);
        CHECK(as_character_set_designation(r[0]).target == 0);
        CHECK(as_character_set_designation(r[0]).set == CSD::UK);
    }
    SECTION("ESC ( B")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "(B"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::designate_character_set);
        CHECK(as_character_set_designation(r[0]).target == 0);
        CHECK(as_character_set_designation(r[0]).set == CSD::USASCII);
    }
    SECTION("ESC ( 1")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "(1"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::designate_character_set);
        CHECK(as_character_set_designation(r[0]).target == 0);
        CHECK(as_character_set_designation(r[0]).set == CSD::AlternateCharacterROMStandardCharacters);
    }
    SECTION("ESC ( 2")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "(2"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::designate_character_set);
        CHECK(as_character_set_designation(r[0]).target == 0);
        CHECK(as_character_set_designation(r[0]).set == CSD::AlternateCharacterROMSpecialGraphics);
    }
    SECTION("ESC ) 0")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       ")0"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::designate_character_set);
        CHECK(as_character_set_designation(r[0]).target == 1);
        CHECK(as_character_set_designation(r[0]).set == CSD::DECSpecialGraphics);
    }
    SECTION("ESC * 0")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "*0"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::designate_character_set);
        CHECK(as_character_set_designation(r[0]).target == 2);
        CHECK(as_character_set_designation(r[0]).set == CSD::DECSpecialGraphics);
    }
    SECTION("ESC + 0")
    {
        auto r = parser.Parse(to_bytes("\x1B"
                                       "+0"));
        REQUIRE(r.size() == 1);
        CHECK(r[0].type == Type::designate_character_set);
        CHECK(as_character_set_designation(r[0]).target == 3);
        CHECK(as_character_set_designation(r[0]).set == CSD::DECSpecialGraphics);
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}

TEST_CASE(PREFIX "CSIParamsScanner")
{
    using S = ParserImpl::CSIParamsScanner;
    SECTION("")
    {
        auto p = S::Parse("");
        CHECK(p.count == 0);
    }
    SECTION("A")
    {
        auto p = S::Parse("A");
        CHECK(p.count == 0);
    }
    SECTION("A11")
    {
        auto p = S::Parse("A");
        CHECK(p.count == 0);
    }
    SECTION("39A")
    {
        auto p = S::Parse("39A");
        CHECK(p.count == 1);
        CHECK(p.values[0] == 39);
    }
    SECTION(";39A")
    {
        auto p = S::Parse(";39A");
        CHECK(p.count == 2);
        CHECK(p.values[0] == 0);
        CHECK(p.values[1] == 39);
    }
    SECTION("39;13A")
    {
        auto p = S::Parse("39;13A");
        CHECK(p.count == 2);
        CHECK(p.values[0] == 39);
        CHECK(p.values[1] == 13);
    }
    SECTION("39;13A")
    {
        auto p = S::Parse("39;13A");
        CHECK(p.count == 2);
        CHECK(p.values[0] == 39);
        CHECK(p.values[1] == 13);
    }
    SECTION("0;1;2;3;4;5;6;7;8;9;10A")
    {
        auto p = S::Parse("0;1;2;3;4;5;6;7;8;9;10A");
        CHECK(p.count == S::MaxParams);
        for( int i = 0; i != S::MaxParams; ++i )
            CHECK(p.values[i] == static_cast<unsigned>(i));
    }
    SECTION("99999999999999999999999999999999999")
    {
        auto p = S::Parse("99999999999999999999999999999999999");
        CHECK(p.count == 0);
    }
    SECTION("7;99999999999999999999999999999999999")
    {
        auto p = S::Parse("7;99999999999999999999999999999999999");
        CHECK(p.count == 1);
        CHECK(p.values[0] == 7);
    }
}

TEST_CASE(PREFIX "Properly handles torn sequences")
{
    ParserImpl parser;
    SECTION("ESC [ 34 P")
    {
        auto r1 = parser.Parse(to_bytes("\x1B"));
        REQUIRE(r1.empty());
        auto r2 = parser.Parse(to_bytes("[34P"));
        REQUIRE(r2.size() == 1);
        CHECK(r2[0].type == Type::delete_characters);
        CHECK(as_unsigned(r2[0]) == 34);
    }
    SECTION("\xf0\x9f\x98\xb1")
    { // 😱
        auto r1 = parser.Parse(to_bytes("\xf0\x9f"));
        REQUIRE(r1.empty());
        auto r2 = parser.Parse(to_bytes("\x98\xb1\xf0\x9f\x98"));
        REQUIRE(r2.size() == 1);
        CHECK(r2[0].type == Type::text);
        CHECK(as_utf8text(r2[0]).characters == "\xf0\x9f\x98\xb1");
        auto r3 = parser.Parse(to_bytes("\xb1"));
        REQUIRE(r3.size() == 1);
        CHECK(r3[0].type == Type::text);
        CHECK(as_utf8text(r3[0]).characters == "\xf0\x9f\x98\xb1");
    }
    CHECK(parser.GetEscState() == ParserImpl::EscState::Text);
}
