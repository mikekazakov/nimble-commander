// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Parser2Impl.h>
#include "Tests.h"

using namespace nc::term;
using namespace nc::term::input;
#define PREFIX "nc::term::Parser2 "

static Parser2::Bytes to_bytes(const char *_characters)
{
    assert( _characters != nullptr );
    return Parser2::Bytes{ reinterpret_cast<const std::byte*>(_characters),
        std::string_view(_characters).size() };
}

static Parser2::Bytes to_bytes(const char8_t *_characters)
{
    assert( _characters != nullptr );
    return Parser2::Bytes{ reinterpret_cast<const std::byte*>(_characters),
        std::u8string_view{_characters}.size()
    };
}

static unsigned as_unsigned( const Command &_command )
{
    if( auto ptr = std::get_if<unsigned>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not unsigned");
}

static signed as_signed( const Command &_command )
{
    if( auto ptr = std::get_if<signed>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not signed");
}

static const UTF8Text& as_utf8text( const Command &_command )
{
    if( auto ptr = std::get_if<UTF8Text>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not UTF8Text");
}

static const Title& as_title( const Command &_command )
{
    if( auto ptr = std::get_if<Title>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not Title");
}

static const CursorMovement& as_cursor_movement( const Command &_command )
{
    if( auto ptr = std::get_if<CursorMovement>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not CursorMovement");
}

static const DisplayErasure& as_display_erasure( const Command &_command )
{
    if( auto ptr = std::get_if<DisplayErasure>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not DisplayErasure");
}

static const LineErasure& as_line_erasure( const Command &_command )
{
    if( auto ptr = std::get_if<LineErasure>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not LineErasure");
}

static const ModeChange& as_mode_change( const Command &_command )
{
    if( auto ptr = std::get_if<ModeChange>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not ModeChange");
}

static const DeviceReport& as_device_report( const Command &_command )
{
    if( auto ptr = std::get_if<DeviceReport>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not DeviceReport");
}

static const ScrollingRegion& as_scrolling_region( const Command &_command )
{
    if( auto ptr = std::get_if<ScrollingRegion>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not ScrollingRegion");
}

static const TabClear& as_tab_clear( const Command &_command )
{
    if( auto ptr = std::get_if<TabClear>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not TabClear");
}

static const CharacterAttributes& as_character_attributes( const Command &_command )
{
    if( auto ptr = std::get_if<CharacterAttributes>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not CharacterAttributes");
}

static const CharacterSetDesignation& as_character_set_designation( const Command &_command )
{
    if( auto ptr = std::get_if<CharacterSetDesignation>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not CharacterSetDesignation");
}

TEST_CASE(PREFIX"Parsing empty data returns nothing")
{
    Parser2Impl parser;
    CHECK( parser.Parse({}).empty() );
}

TEST_CASE(PREFIX"Parsing raw ascii text yields it")
{
    Parser2Impl parser;
    SECTION( "Single character" ) {
        auto r = parser.Parse(to_bytes("t"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::text );
        CHECK( as_utf8text(r[0]).characters == "t" );
    }
    SECTION( "Two characters" ) {
        auto r = parser.Parse(to_bytes("qp"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::text );
        CHECK( as_utf8text(r[0]).characters == "qp" );
    }
    SECTION( "Multiple characters" ) {
        auto r = parser.Parse(to_bytes("Hello, World!"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::text );
        CHECK( as_utf8text(r[0]).characters == "Hello, World!" );
    }
    SECTION("Smile") {
        auto r = parser.Parse(to_bytes(u8"🤩"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::text );
        CHECK( as_utf8text(r[0]).characters == reinterpret_cast<const char*>(u8"🤩") );
    }
    SECTION("Variable length") {
        auto r = parser.Parse(to_bytes(u8"This is какая-то смесь языков 😱!"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::text );
        CHECK( as_utf8text(r[0]).characters ==
              reinterpret_cast<const char*>(u8"This is какая-то смесь языков 😱!") );
    }
}

TEST_CASE(PREFIX"Handles control characters")
{
    Parser2Impl parser;
    SECTION( "unused" ) {
        std::vector<input::Command> r;
        SECTION( "0" ) { r = parser.Parse(to_bytes("\x00")); }
        SECTION( "1" ) { r = parser.Parse(to_bytes("\x01")); }
        SECTION( "2" ) { r = parser.Parse(to_bytes("\x02")); }
        SECTION( "3" ) { r = parser.Parse(to_bytes("\x03")); }
        SECTION( "4" ) { r = parser.Parse(to_bytes("\x04")); }
        SECTION( "5" ) { r = parser.Parse(to_bytes("\x05")); }
        SECTION( "6" ) { r = parser.Parse(to_bytes("\x06")); }
        SECTION( "16" ) { r = parser.Parse(to_bytes("\x10")); }
        SECTION( "17" ) { r = parser.Parse(to_bytes("\x11")); }
        SECTION( "18" ) { r = parser.Parse(to_bytes("\x12")); }
        SECTION( "19" ) { r = parser.Parse(to_bytes("\x13")); }
        SECTION( "20" ) { r = parser.Parse(to_bytes("\x14")); }
        SECTION( "21" ) { r = parser.Parse(to_bytes("\x15")); }
        SECTION( "22" ) { r = parser.Parse(to_bytes("\x16")); }
        SECTION( "23" ) { r = parser.Parse(to_bytes("\x17")); }        
        SECTION( "25" ) { r = parser.Parse(to_bytes("\x19")); }
        SECTION( "28" ) { r = parser.Parse(to_bytes("\x1C")); }
        SECTION( "29" ) { r = parser.Parse(to_bytes("\x1D")); }
        SECTION( "30" ) { r = parser.Parse(to_bytes("\x1E")); }
        SECTION( "31" ) { r = parser.Parse(to_bytes("\x1F")); }
        CHECK( r.size() == 0 );
    }
    SECTION( "linefeed" ) {
        std::vector<input::Command> r;
        SECTION( "10" ) { r = parser.Parse(to_bytes("\x0A")); }
        SECTION( "11" ) { r = parser.Parse(to_bytes("\x0B")); }
        SECTION( "12" ) { r = parser.Parse(to_bytes("\x0C")); }
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::line_feed );
    }
    SECTION( "horizontal tab" ) {
        auto r = parser.Parse(to_bytes("\t"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::horizontal_tab );
        CHECK( as_signed(r[0]) == 1 );
    }
    SECTION( "carriage return" ) {
        auto r = parser.Parse(to_bytes("\x0D"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::carriage_return );
    }
    SECTION( "backspace" ) {
        auto r = parser.Parse(to_bytes("\x08"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::back_space );
    }
    SECTION( "bell" ) {
        auto r = parser.Parse(to_bytes("\x07"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::bell );
    }
    SECTION( "go into escape mode" ) {
        auto r = parser.Parse(to_bytes("\x1B"));
        REQUIRE( r.empty() );
        CHECK( parser.GetEscState() == Parser2Impl::EscState::Esc );
        parser.Parse(to_bytes("\x18"));
    }
    SECTION( "go to normal mode" ) {
        std::vector<input::Command> r;
        SECTION("") { r = parser.Parse(to_bytes("\x18")); }
        SECTION("") { r = parser.Parse(to_bytes("\x1A")); }
        SECTION("") { r = parser.Parse(to_bytes("\x1B\x18")); }
        SECTION("") { r = parser.Parse(to_bytes("\x1B\x1A")); }
        REQUIRE( r.empty() );
    }
    SECTION( "select g1" ) {
        auto r = parser.Parse(to_bytes("\x0E"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::select_character_set );
        CHECK( as_unsigned(r[0]) == 1 );
    }
    SECTION( "select g0" ) {
        auto r = parser.Parse(to_bytes("\x0F"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::select_character_set );
        CHECK( as_unsigned(r[0]) == 0 );
    }
    SECTION( "ESC E" ) {
        auto r = parser.Parse(to_bytes("\x1B""E"));
        REQUIRE( r.size() == 2 );
        CHECK( r[0].type == Type::carriage_return );
        CHECK( r[1].type == Type::line_feed );
    }
    SECTION( "ESC H" ) {
        auto r = parser.Parse(to_bytes("\x1B""H"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::set_tab );
    }
    SECTION( "ESC D" ) {
        auto r = parser.Parse(to_bytes("\x1B""D"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::line_feed );
    }
    SECTION( "ESC M" ) {
        auto r = parser.Parse(to_bytes("\x1B""M"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::reverse_index );
    }
    SECTION( "ESC c" ) {
        auto r = parser.Parse(to_bytes("\x1B""c"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::reset );
    }
    SECTION( "ESC 7" ) {
        auto r = parser.Parse(to_bytes("\x1B""7"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::save_state );
    }
    SECTION( "ESC 8" ) {
        auto r = parser.Parse(to_bytes("\x1B""8"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::restore_state );
    }
    SECTION( "ESC # 8" ) {
        auto r = parser.Parse(to_bytes("\x1B""#8"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::screen_alignment_test );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"OSC")
{
    Parser2Impl parser;
    SECTION( "ESC ] 0 ; Hello" ) {
        std::vector<input::Command> r;
        SECTION("") { r = parser.Parse(to_bytes("\x1B""]0;Hello\x07")); }    
        SECTION("") { r = parser.Parse(to_bytes("\x1B""]0;Hello\x1B\\")); }
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::change_title );
        CHECK( as_title(r[0]).kind == Title::IconAndWindow );
        CHECK( as_title(r[0]).title == "Hello" );
    }
    SECTION( "ESC ] 1 ; Hello" ) {
        std::vector<input::Command> r;
        SECTION("") { r = parser.Parse(to_bytes("\x1B""]1;Hello\x07")); }    
        SECTION("") { r = parser.Parse(to_bytes("\x1B""]1;Hello\x1B\\")); }
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::change_title );
        CHECK( as_title(r[0]).kind == Title::Icon );
        CHECK( as_title(r[0]).title == "Hello" );
    }
    SECTION( "ESC ] 2 ; Hello" ) {
        std::vector<input::Command> r;
        SECTION("") { r = parser.Parse(to_bytes("\x1B""]2;Hello\x07")); }    
        SECTION("") { r = parser.Parse(to_bytes("\x1B""]2;Hello\x1B\\")); }
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::change_title );
        CHECK( as_title(r[0]).kind == Title::Window );
        CHECK( as_title(r[0]).title == "Hello" );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI A")
{
    Parser2Impl parser;
    SECTION( "ESC [ A" ) {
        auto r = parser.Parse(to_bytes("\x1B""[A"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y == -1 );     
    }
    SECTION( "ESC [ 0 A" ) {
        auto r = parser.Parse(to_bytes("\x1B""[0A"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y == -1 );
    }
    SECTION( "ESC [ 27 A" ) {
        auto r = parser.Parse(to_bytes("\x1B""[27A"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y == -27 );     
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI B")
{
    Parser2Impl parser;
    SECTION( "ESC [ B" ) {
        auto r = parser.Parse(to_bytes("\x1B""[B"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y == 1 );     
    }
    SECTION( "ESC [ 0 B" ) {
        auto r = parser.Parse(to_bytes("\x1B""[0B"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y == 1 );
    }
    SECTION( "ESC [ 45 A" ) {
        auto r = parser.Parse(to_bytes("\x1B""[45B"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y == 45 );     
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI C")
{
    Parser2Impl parser;
    SECTION( "ESC [ C" ) {
        auto r = parser.Parse(to_bytes("\x1B""[C"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == 1 );
        CHECK( as_cursor_movement(r[0]).y == 0 );     
    }
    SECTION( "ESC [ 0 C" ) {
        auto r = parser.Parse(to_bytes("\x1B""[0C"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == 1 );
        CHECK( as_cursor_movement(r[0]).y == 0 );
    }
    SECTION( "ESC [ 42 C" ) {
        auto r = parser.Parse(to_bytes("\x1B""[42C"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == 42 );
        CHECK( as_cursor_movement(r[0]).y == 0 );     
    }
    SECTION( "ESC [ 2 BS C" ) {
        auto r = parser.Parse(to_bytes("\x1B[2\x08""C"));
        REQUIRE( r.size() == 2 );
        CHECK( r[0].type == Type::back_space );        
        CHECK( r[1].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[1]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[1]).x == 2 );
        CHECK( as_cursor_movement(r[1]).y == 0 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI D")
{
    Parser2Impl parser;
    SECTION( "ESC [ D" ) {
        auto r = parser.Parse(to_bytes("\x1B""[D"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == -1 );
        CHECK( as_cursor_movement(r[0]).y == 0 );     
    }
    SECTION( "ESC [ 0 D" ) {
        auto r = parser.Parse(to_bytes("\x1B""[0D"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == -1 );
        CHECK( as_cursor_movement(r[0]).y == 0 );
    }
    SECTION( "ESC [ 32 D" ) {
        auto r = parser.Parse(to_bytes("\x1B""[32D"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == -32 );
        CHECK( as_cursor_movement(r[0]).y == 0 );     
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI E")
{
    Parser2Impl parser;
    SECTION( "ESC [ E" ) {
        auto r = parser.Parse(to_bytes("\x1B""[E"));
        REQUIRE( r.size() == 2 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == std::nullopt );
        CHECK( as_cursor_movement(r[0]).y == 1 );
        CHECK( r[1].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[1]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[1]).x == 0 );
        CHECK( as_cursor_movement(r[1]).y == std::nullopt );
    }
    SECTION( "ESC [ 7 E" ) {
        auto r = parser.Parse(to_bytes("\x1B""[7E"));
        REQUIRE( r.size() == 2 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == std::nullopt );
        CHECK( as_cursor_movement(r[0]).y == 7 );
        CHECK( r[1].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[1]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[1]).x == 0 );
        CHECK( as_cursor_movement(r[1]).y == std::nullopt );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI F")
{
    Parser2Impl parser;
    SECTION( "ESC [ F" ) {
        auto r = parser.Parse(to_bytes("\x1B""[F"));
        REQUIRE( r.size() == 2 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == std::nullopt );
        CHECK( as_cursor_movement(r[0]).y == -1 );
        CHECK( r[1].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[1]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[1]).x == 0 );
        CHECK( as_cursor_movement(r[1]).y == std::nullopt );
    }
    SECTION( "ESC [ 8 F" ) {
        auto r = parser.Parse(to_bytes("\x1B""[8F"));
        REQUIRE( r.size() == 2 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == std::nullopt );
        CHECK( as_cursor_movement(r[0]).y == -8 );
        CHECK( r[1].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[1]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[1]).x == 0 );
        CHECK( as_cursor_movement(r[1]).y == std::nullopt );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI G")
{
    Parser2Impl parser;
    SECTION( "ESC [ G" ) {
        auto r = parser.Parse(to_bytes("\x1B""[G"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y.has_value() == false );     
    }
    SECTION( "ESC [ 71 G" ) {
        auto r = parser.Parse(to_bytes("\x1B""[71G"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[0]).x == 70 );
        CHECK( as_cursor_movement(r[0]).y.has_value() == false );     
    }
    SECTION( "ESC [ 0 G" ) {
        auto r = parser.Parse(to_bytes("\x1B""[0G"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y.has_value() == false );     
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI H")
{
    Parser2Impl parser;
    SECTION( "ESC [ H" ) {
        auto r = parser.Parse(to_bytes("\x1B""[H"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y == 0 );     
    }
    SECTION( "ESC [ 5 ; 10 H" ) {
        auto r = parser.Parse(to_bytes("\x1B""[5;10H"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[0]).x == 9 );
        CHECK( as_cursor_movement(r[0]).y == 4 );     
    }
    SECTION( "ESC [ 0 ; 0 H" ) {
        auto r = parser.Parse(to_bytes("\x1B""[0;0H"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y == 0 );     
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI I")
{
    Parser2Impl parser;
    SECTION( "ESC [ I" ) {
        auto r = parser.Parse(to_bytes("\x1B""[I"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::horizontal_tab );
        CHECK( as_signed(r[0]) == 1 );
    }
    SECTION( "ESC [ 123 I" ) {
        auto r = parser.Parse(to_bytes("\x1B""[123I"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::horizontal_tab );
        CHECK( as_signed(r[0]) == 123 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI J")
{
    Parser2Impl parser;
    using Area = DisplayErasure::Area;
    SECTION( "ESC [ J" ) {
        auto r = parser.Parse(to_bytes("\x1B""[J"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::erase_in_display );
        CHECK( as_display_erasure(r[0]).what_to_erase == Area::FromCursorToDisplayEnd );
    }
    SECTION( "ESC [ 0 J" ) {
        auto r = parser.Parse(to_bytes("\x1B""[0J"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::erase_in_display );
        CHECK( as_display_erasure(r[0]).what_to_erase == Area::FromCursorToDisplayEnd );
    }
    SECTION( "ESC [ 1 J" ) {
        auto r = parser.Parse(to_bytes("\x1B""[1J"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::erase_in_display );
        CHECK( as_display_erasure(r[0]).what_to_erase == Area::FromDisplayStartToCursor );
    }
    SECTION( "ESC [ 2 J" ) {
        auto r = parser.Parse(to_bytes("\x1B""[2J"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::erase_in_display );
        CHECK( as_display_erasure(r[0]).what_to_erase == Area::WholeDisplay );
    }
    SECTION( "ESC [ 3 J" ) {
        auto r = parser.Parse(to_bytes("\x1B""[3J"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::erase_in_display );
        CHECK( as_display_erasure(r[0]).what_to_erase == Area::WholeDisplayWithScrollback );
    }
    SECTION( "ESC [ 4 J" ) {
        auto r = parser.Parse(to_bytes("\x1B""[4J"));
        REQUIRE( r.size() == 0 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI K")
{
    Parser2Impl parser;
    using Area = LineErasure::Area;
    SECTION( "ESC [ K" ) {
        auto r = parser.Parse(to_bytes("\x1B""[K"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::erase_in_line );
        CHECK( as_line_erasure(r[0]).what_to_erase == Area::FromCursorToLineEnd );
    }
    SECTION( "ESC [ 0 K" ) {
        auto r = parser.Parse(to_bytes("\x1B""[0K"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::erase_in_line );
        CHECK( as_line_erasure(r[0]).what_to_erase == Area::FromCursorToLineEnd );
    }
    SECTION( "ESC [ 1 K" ) {
        auto r = parser.Parse(to_bytes("\x1B""[1K"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::erase_in_line );
        CHECK( as_line_erasure(r[0]).what_to_erase == Area::FromLineStartToCursor );
    }
    SECTION( "ESC [ 2 K" ) {
        auto r = parser.Parse(to_bytes("\x1B""[2K"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::erase_in_line );
        CHECK( as_line_erasure(r[0]).what_to_erase == Area::WholeLine );
    }
    SECTION( "ESC [ 3 K" ) {
        auto r = parser.Parse(to_bytes("\x1B""[3K"));
        REQUIRE( r.size() == 0 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI L")
{
    Parser2Impl parser;
    SECTION( "ESC [ L" ) {
        auto r = parser.Parse(to_bytes("\x1B""[L"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::insert_lines );
        CHECK( as_unsigned(r[0]) == 1 );
    }
    SECTION( "ESC [ 12 L" ) {
        auto r = parser.Parse(to_bytes("\x1B""[12L"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::insert_lines );
        CHECK( as_unsigned(r[0]) == 12 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI M")
{
    Parser2Impl parser;
    SECTION( "ESC [ M" ) {
        auto r = parser.Parse(to_bytes("\x1B""[M"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::delete_lines );
        CHECK( as_unsigned(r[0]) == 1 );
    }
    SECTION( "ESC [ 23 M" ) {
        auto r = parser.Parse(to_bytes("\x1B""[23M"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::delete_lines );
        CHECK( as_unsigned(r[0]) == 23 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI P")
{
    Parser2Impl parser;
    SECTION( "ESC [ P" ) {
        auto r = parser.Parse(to_bytes("\x1B""[P"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::delete_characters );
        CHECK( as_unsigned(r[0]) == 1 );
    }
    SECTION( "ESC [ 34 P" ) {
        auto r = parser.Parse(to_bytes("\x1B""[34P"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::delete_characters );
        CHECK( as_unsigned(r[0]) == 34 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI S")
{
    Parser2Impl parser;
    SECTION( "ESC [ S" ) {
        auto r = parser.Parse(to_bytes("\x1B""[S"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::scroll_lines );
        CHECK( as_signed(r[0]) == 1 );
    }
    SECTION( "ESC [ 45 S" ) {
        auto r = parser.Parse(to_bytes("\x1B""[45S"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::scroll_lines );
        CHECK( as_signed(r[0]) == 45 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI T")
{
    Parser2Impl parser;
    SECTION( "ESC [ T" ) {
        auto r = parser.Parse(to_bytes("\x1B""[T"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::scroll_lines );
        CHECK( as_signed(r[0]) == -1 );
    }
    SECTION( "ESC [ 56 T" ) {
        auto r = parser.Parse(to_bytes("\x1B""[56T"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::scroll_lines );
        CHECK( as_signed(r[0]) == -56 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI X")
{
    Parser2Impl parser;
    SECTION( "ESC [ X" ) {
        auto r = parser.Parse(to_bytes("\x1B""[X"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::erase_characters );
        CHECK( as_unsigned(r[0]) == 1 );
    }
    SECTION( "ESC [ 67 X" ) {
        auto r = parser.Parse(to_bytes("\x1B""[67X"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::erase_characters );
        CHECK( as_unsigned(r[0]) == 67 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI Z")
{
    Parser2Impl parser;
    SECTION( "ESC [ Z" ) {
        auto r = parser.Parse(to_bytes("\x1B""[Z"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::horizontal_tab );
        CHECK( as_signed(r[0]) == -1 );
    }
    SECTION( "ESC [ 1234 Z" ) {
        auto r = parser.Parse(to_bytes("\x1B""[1234Z"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::horizontal_tab );
        CHECK( as_signed(r[0]) == -1234 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI a")
{
    Parser2Impl parser;
    SECTION( "ESC [ a" ) {
        auto r = parser.Parse(to_bytes("\x1B""[a"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Relative );
        CHECK( as_cursor_movement(r[0]).x == 1 );
        CHECK( as_cursor_movement(r[0]).y == std::nullopt );
    }
    SECTION( "ESC [ 7 a" ) {
        auto r = parser.Parse(to_bytes("\x1B""[7a"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Relative );
        CHECK( as_cursor_movement(r[0]).x == 7 );
        CHECK( as_cursor_movement(r[0]).y == std::nullopt );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI b")
{
    Parser2Impl parser;
    SECTION( "ESC [ b" ) {
        auto r = parser.Parse(to_bytes("\x1B""[b"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::repeat_last_character );
        CHECK( as_unsigned(r[0]) == 1 );
    }
    SECTION( "ESC [ 7 b" ) {
        auto r = parser.Parse(to_bytes("\x1B""[7b"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::repeat_last_character );
        CHECK( as_unsigned(r[0]) == 7 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI c")
{
    Parser2Impl parser;
    SECTION( "ESC [ c" ) {
        auto r = parser.Parse(to_bytes("\x1B""[c"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::report );
        CHECK( as_device_report(r[0]).mode == DeviceReport::Kind::TerminalId );
    }
    SECTION( "ESC [ 0 c" ) {
        auto r = parser.Parse(to_bytes("\x1B""[0c"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::report );
        CHECK( as_device_report(r[0]).mode == DeviceReport::Kind::TerminalId );
    }
    SECTION( "ESC [ 1 c" ) {
        auto r = parser.Parse(to_bytes("\x1B""[1c"));
        REQUIRE( r.empty() );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI d")
{
    Parser2Impl parser;
    SECTION( "ESC [ d" ) {
        auto r = parser.Parse(to_bytes("\x1B""[d"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Absolute );
        CHECK( as_cursor_movement(r[0]).x == std::nullopt );
        CHECK( as_cursor_movement(r[0]).y == 0 );
    }
    SECTION( "ESC [ 5 d" ) {
        auto r = parser.Parse(to_bytes("\x1B""[5d"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Absolute );
        CHECK( as_cursor_movement(r[0]).x == std::nullopt );
        CHECK( as_cursor_movement(r[0]).y == 4 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI e")
{
    Parser2Impl parser;
    SECTION( "ESC [ e" ) {
        auto r = parser.Parse(to_bytes("\x1B""[e"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Relative );
        CHECK( as_cursor_movement(r[0]).x == std::nullopt );
        CHECK( as_cursor_movement(r[0]).y == 1 );
    }
    SECTION( "ESC [ 5 e" ) {
        auto r = parser.Parse(to_bytes("\x1B""[5e"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Relative );
        CHECK( as_cursor_movement(r[0]).x == std::nullopt );
        CHECK( as_cursor_movement(r[0]).y == 5 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI f")
{
    Parser2Impl parser;
    SECTION( "ESC [ f" ) {
        auto r = parser.Parse(to_bytes("\x1B""[f"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y == 0 );
    }
    SECTION( "ESC [ 5 ; 10 f" ) {
        auto r = parser.Parse(to_bytes("\x1B""[5;10f"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[0]).x == 9 );
        CHECK( as_cursor_movement(r[0]).y == 4 );
    }
    SECTION( "ESC [ 0 ; 0 f" ) {
        auto r = parser.Parse(to_bytes("\x1B""[0;0f"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Absolute );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y == 0 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI g")
{
    Parser2Impl parser;
    SECTION( "ESC [ g" ) {
        auto r = parser.Parse(to_bytes("\x1B""[g"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::clear_tab );
        CHECK( as_tab_clear(r[0]).mode == input::TabClear::CurrentColumn );
    }
    SECTION( "ESC [ 0 g" ) {
        auto r = parser.Parse(to_bytes("\x1B""[0g"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::clear_tab );
        CHECK( as_tab_clear(r[0]).mode == input::TabClear::CurrentColumn );
    }
    SECTION( "ESC [ 1 g" ) {
        auto r = parser.Parse(to_bytes("\x1B""[1g"));
        CHECK( r.size() == 0 );
    }
    SECTION( "ESC [ 2 g" ) {
        auto r = parser.Parse(to_bytes("\x1B""[2g"));
        CHECK( r.size() == 0 );
    }
    SECTION( "ESC [ 3 g" ) {
        auto r = parser.Parse(to_bytes("\x1B""[3g"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::clear_tab );
        CHECK( as_tab_clear(r[0]).mode == input::TabClear::All );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI hl")
{
    Parser2Impl parser;
    using Kind = ModeChange::Kind;
    auto verify = [&](const char *_cmd, Kind _kind, bool _status ) {
        auto r = parser.Parse(to_bytes(_cmd));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::change_mode );
        CHECK( as_mode_change(r[0]).mode == _kind );
        CHECK( as_mode_change(r[0]).status == _status );
    };
    SECTION( "ESC [ 4 h" ) {
        verify("\x1B""[4h", Kind::Insert, true);
    }
    SECTION( "ESC [ 4 l" ) {
        verify("\x1B""[4l", Kind::Insert, false);
    }
    SECTION( "ESC [ 20 h" ) {
        verify("\x1B""[20h", Kind::NewLine, true);
    }
    SECTION( "ESC [ 20 l" ) {
        verify("\x1B""[20l", Kind::NewLine, false);
    }
    SECTION( "ESC [ ? 1 h" ) {
        verify("\x1B""[?1h", Kind::ApplicationCursorKeys, true);
    }
    SECTION( "ESC [ ? 1 l" ) {
        verify("\x1B""[?1l", Kind::ApplicationCursorKeys, false);
    }
    SECTION( "ESC [ ? 3 h" ) {
        verify("\x1B""[?3h", Kind::Column132, true);
    }
    SECTION( "ESC [ ? 3 l" ) {
        verify("\x1B""[?3l", Kind::Column132, false);
    }
    SECTION( "ESC [ ? 4 h" ) {
        verify("\x1B""[?4h", Kind::SmoothScroll, true);
    }
    SECTION( "ESC [ ? 4 l" ) {
        verify("\x1B""[?4l", Kind::SmoothScroll, false);
    }
    SECTION( "ESC [ ? 5 h" ) {
        verify("\x1B""[?5h", Kind::ReverseVideo, true);
    }
    SECTION( "ESC [ ? 5 l" ) {
        verify("\x1B""[?5l", Kind::ReverseVideo, false);
    }
    SECTION( "ESC [ ? 6 h" ) {
        verify("\x1B""[?6h", Kind::Origin, true);
    }
    SECTION( "ESC [ ? 6 l" ) {
        verify("\x1B""[?6l", Kind::Origin, false);
    }
    SECTION( "ESC [ ? 7 h" ) {
        verify("\x1B""[?7h", Kind::AutoWrap, true);
    }
    SECTION( "ESC [ ? 7 l" ) {
        verify("\x1B""[?7l", Kind::AutoWrap, false);
    }
    SECTION( "ESC [ ? 12 h" ) {
        verify("\x1B""[?12h", Kind::BlinkingCursor, true);
    }
    SECTION( "ESC [ ? 12 l" ) {
        verify("\x1B""[?12l", Kind::BlinkingCursor, false);
    }
    SECTION( "ESC [ ? 25 h" ) {
        verify("\x1B""[?25h", Kind::ShowCursor, true);
    }
    SECTION( "ESC [ ? 25 l" ) {
        verify("\x1B""[?25l", Kind::ShowCursor, false);
    }
    SECTION( "ESC [ ? 47 h" ) {
        verify("\x1B""[?47h", Kind::AlternateScreenBuffer, true);
    }
    SECTION( "ESC [ ? 47 l" ) {
        verify("\x1B""[?47l", Kind::AlternateScreenBuffer, false);
    }
    SECTION( "ESC [ ? 1049 h" ) {
        verify("\x1B""[?1049h", Kind::AlternateScreenBuffer1049, true);
    }
    SECTION( "ESC [ ? 1049 l" ) {
        verify("\x1B""[?1049l", Kind::AlternateScreenBuffer1049, false);
    }
    SECTION( "ESC [ h" ) {
        REQUIRE( parser.Parse(to_bytes("\x1B""[h")).empty() );
    }
    SECTION( "ESC [ l" ) {
        REQUIRE( parser.Parse(to_bytes("\x1B""[l")).empty() );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI m")
{
    Parser2Impl parser;
    auto verify = [&](const char *_cmd, CharacterAttributes::Kind _mode) {
        auto r = parser.Parse(to_bytes(_cmd));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::set_character_attributes );
        CHECK( as_character_attributes(r[0]).mode == _mode );
    };
    SECTION( "ESC [ m" ) {
        verify("\x1B[m", CharacterAttributes::Normal);
    }
    SECTION( "ESC [ 0 m" ) {
        verify("\x1B[0m", CharacterAttributes::Normal);
    }
    SECTION( "ESC [ 1 m" ) {
        verify("\x1B[1m", CharacterAttributes::Bold);
    }
    SECTION( "ESC [ ; 1 m" ) {
        auto r = parser.Parse(to_bytes("\x1B[;1m"));
        REQUIRE( r.size() == 2 );
        CHECK( r[0].type == Type::set_character_attributes );
        CHECK( as_character_attributes(r[0]).mode == CharacterAttributes::Normal );
        CHECK( r[1].type == Type::set_character_attributes );
        CHECK( as_character_attributes(r[1]).mode == CharacterAttributes::Bold );
    }
    SECTION( "ESC [ 0 ; 1 m" ) {
        auto r = parser.Parse(to_bytes("\x1B[0;1m"));
        REQUIRE( r.size() == 2 );
        CHECK( r[0].type == Type::set_character_attributes );
        CHECK( as_character_attributes(r[0]).mode == CharacterAttributes::Normal );
        CHECK( r[1].type == Type::set_character_attributes );
        CHECK( as_character_attributes(r[1]).mode == CharacterAttributes::Bold );
    }
    SECTION( "ESC [ 2 m" ) {
        verify("\x1B[2m", CharacterAttributes::Faint);
    }
    SECTION( "ESC [ 3 m" ) {
        verify("\x1B[3m", CharacterAttributes::Italicized);
    }
    SECTION( "ESC [ 4 m" ) {
        verify("\x1B[4m", CharacterAttributes::Underlined);
    }
    SECTION( "ESC [ 5 m" ) {
        verify("\x1B[5m", CharacterAttributes::Blink);
    }
    SECTION( "ESC [ 7 m" ) {
        verify("\x1B[7m", CharacterAttributes::Inverse);
    }
    SECTION( "ESC [ 8 m" ) {
        verify("\x1B[8m", CharacterAttributes::Invisible);
    }
    SECTION( "ESC [ 9 m" ) {
        verify("\x1B[9m", CharacterAttributes::Crossed);
    }
    SECTION( "ESC [ 21 m" ) {
        verify("\x1B[21m", CharacterAttributes::DoublyUnderlined);
    }
    SECTION( "ESC [ 22 m" ) {
        verify("\x1B[22m", CharacterAttributes::NotBoldNotFaint);
    }
    SECTION( "ESC [ 23 m" ) {
        verify("\x1B[23m", CharacterAttributes::NotItalicized);
    }
    SECTION( "ESC [ 24 m" ) {
        verify("\x1B[24m", CharacterAttributes::NotUnderlined);
    }
    SECTION( "ESC [ 25 m" ) {
        verify("\x1B[25m", CharacterAttributes::NotBlink);
    }
    SECTION( "ESC [ 27 m" ) {
        verify("\x1B[27m", CharacterAttributes::NotInverse);
    }
    SECTION( "ESC [ 28 m" ) {
        verify("\x1B[28m", CharacterAttributes::NotInvisible);
    }
    SECTION( "ESC [ 29 m" ) {
        verify("\x1B[29m", CharacterAttributes::NotCrossed);
    }
    SECTION( "ESC [ 30 m" ) {
        verify("\x1B[30m", CharacterAttributes::ForegroundBlack);
    }
    SECTION( "ESC [ 31 m" ) {
        verify("\x1B[31m", CharacterAttributes::ForegroundRed);
    }
    SECTION( "ESC [ 32 m" ) {
        verify("\x1B[32m", CharacterAttributes::ForegroundGreen);
    }
    SECTION( "ESC [ 33 m" ) {
        verify("\x1B[33m", CharacterAttributes::ForegroundYellow);
    }
    SECTION( "ESC [ 34 m" ) {
        verify("\x1B[34m", CharacterAttributes::ForegroundBlue);
    }
    SECTION( "ESC [ 35 m" ) {
        verify("\x1B[35m", CharacterAttributes::ForegroundMagenta);
    }
    SECTION( "ESC [ 36 m" ) {
        verify("\x1B[36m", CharacterAttributes::ForegroundCyan);
    }
    SECTION( "ESC [ 37 m" ) {
        verify("\x1B[37m", CharacterAttributes::ForegroundWhite);
    }
    SECTION( "ESC [ 39 m" ) {
        verify("\x1B[39m", CharacterAttributes::ForegroundDefault);
    }
    SECTION( "ESC [ 40 m" ) {
        verify("\x1B[40m", CharacterAttributes::BackgroundBlack);
    }
    SECTION( "ESC [ 41 m" ) {
        verify("\x1B[41m", CharacterAttributes::BackgroundRed);
    }
    SECTION( "ESC [ 42 m" ) {
        verify("\x1B[42m", CharacterAttributes::BackgroundGreen);
    }
    SECTION( "ESC [ 43 m" ) {
        verify("\x1B[43m", CharacterAttributes::BackgroundYellow);
    }
    SECTION( "ESC [ 44 m" ) {
        verify("\x1B[44m", CharacterAttributes::BackgroundBlue);
    }
    SECTION( "ESC [ 45 m" ) {
        verify("\x1B[45m", CharacterAttributes::BackgroundMagenta);
    }
    SECTION( "ESC [ 46 m" ) {
        verify("\x1B[46m", CharacterAttributes::BackgroundCyan);
    }
    SECTION( "ESC [ 47 m" ) {
        verify("\x1B[47m", CharacterAttributes::BackgroundWhite);
    }
    SECTION( "ESC [ 49 m" ) {
        verify("\x1B[49m", CharacterAttributes::BackgroundDefault);
    }
    SECTION( "ESC [ 90 m" ) {
        verify("\x1B[90m", CharacterAttributes::ForegroundBlackBright);
    }
    SECTION( "ESC [ 91 m" ) {
        verify("\x1B[91m", CharacterAttributes::ForegroundRedBright);
    }
    SECTION( "ESC [ 92 m" ) {
        verify("\x1B[92m", CharacterAttributes::ForegroundGreenBright);
    }
    SECTION( "ESC [ 93 m" ) {
        verify("\x1B[93m", CharacterAttributes::ForegroundYellowBright);
    }
    SECTION( "ESC [ 94 m" ) {
        verify("\x1B[94m", CharacterAttributes::ForegroundBlueBright);
    }
    SECTION( "ESC [ 95 m" ) {
        verify("\x1B[95m", CharacterAttributes::ForegroundMagentaBright);
    }
    SECTION( "ESC [ 96 m" ) {
        verify("\x1B[96m", CharacterAttributes::ForegroundCyanBright);
    }
    SECTION( "ESC [ 97 m" ) {
        verify("\x1B[97m", CharacterAttributes::ForegroundWhiteBright);
    }
    SECTION( "ESC [ 100 m" ) {
        verify("\x1B[100m", CharacterAttributes::BackgroundBlackBright);
    }
    SECTION( "ESC [ 101 m" ) {
        verify("\x1B[101m", CharacterAttributes::BackgroundRedBright);
    }
    SECTION( "ESC [ 102 m" ) {
        verify("\x1B[102m", CharacterAttributes::BackgroundGreenBright);
    }
    SECTION( "ESC [ 103 m" ) {
        verify("\x1B[103m", CharacterAttributes::BackgroundYellowBright);
    }
    SECTION( "ESC [ 104 m" ) {
        verify("\x1B[104m", CharacterAttributes::BackgroundBlueBright);
    }
    SECTION( "ESC [ 105 m" ) {
        verify("\x1B[105m", CharacterAttributes::BackgroundMagentaBright);
    }
    SECTION( "ESC [ 106 m" ) {
        verify("\x1B[106m", CharacterAttributes::BackgroundCyanBright);
    }
    SECTION( "ESC [ 107 m" ) {
        verify("\x1B[107m", CharacterAttributes::BackgroundWhiteBright);
    }
    
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI n")
{
    Parser2Impl parser;
    SECTION( "ESC [ 5 n" ) {
        auto r = parser.Parse(to_bytes("\x1B""[5n"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::report );
        CHECK( as_device_report(r[0]).mode == DeviceReport::DeviceStatus );
    }
    SECTION( "ESC [ 6 n" ) {
        auto r = parser.Parse(to_bytes("\x1B""[6n"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::report );
        CHECK( as_device_report(r[0]).mode == DeviceReport::CursorPosition );
    }
    SECTION( "ESC [ n" ) {
        auto r = parser.Parse(to_bytes("\x1B""[n"));
        REQUIRE( r.size() == 0 );
    }
    SECTION( "ESC [ 0 n" ) {
        auto r = parser.Parse(to_bytes("\x1B""[0n"));
        REQUIRE( r.size() == 0 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI r")
{
    Parser2Impl parser;
    SECTION( "ESC [ r" ) {
        auto r = parser.Parse(to_bytes("\x1B[r"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::set_scrolling_region );
        CHECK( as_scrolling_region(r[0]).range == std::nullopt );
    }
    SECTION( "ESC [ 0 ; 0 r" ) {
        auto r = parser.Parse(to_bytes("\x1B[0;0r"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::set_scrolling_region );
        CHECK( as_scrolling_region(r[0]).range == std::nullopt );
    }
    SECTION( "ESC [ 5 ; 15 r" ) {
        auto r = parser.Parse(to_bytes("\x1B[5;15r"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::set_scrolling_region );
        REQUIRE( as_scrolling_region(r[0]).range != std::nullopt );
        CHECK( as_scrolling_region(r[0]).range->top == 4 );
        CHECK( as_scrolling_region(r[0]).range->bottom == 15 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI `")
{
    Parser2Impl parser;
    SECTION( "ESC [ `" ) {
        auto r = parser.Parse(to_bytes("\x1B""[`"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Absolute );
        CHECK( as_cursor_movement(r[0]).x == 0 );
        CHECK( as_cursor_movement(r[0]).y == std::nullopt );
    }
    SECTION( "ESC [ 7 `" ) {
        auto r = parser.Parse(to_bytes("\x1B""[7`"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Positioning::Absolute );
        CHECK( as_cursor_movement(r[0]).x == 6 );
        CHECK( as_cursor_movement(r[0]).y == std::nullopt );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSI @")
{
    Parser2Impl parser;
    SECTION( "ESC [ @" ) {
        auto r = parser.Parse(to_bytes("\x1B""[@"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::insert_characters );
        CHECK( as_unsigned(r[0]) == 1 );
    }
    SECTION( "ESC [ 42 @" ) {
        auto r = parser.Parse(to_bytes("\x1B""[42@"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::insert_characters );
        CHECK( as_unsigned(r[0]) == 42 );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"Character set designation")
{
    Parser2Impl parser;
    using CSD = CharacterSetDesignation;
    SECTION( "ESC ( 0" ) {
        auto r = parser.Parse(to_bytes("\x1B""(0"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::designate_character_set );
        CHECK( as_character_set_designation(r[0]).target == 0 );
        CHECK( as_character_set_designation(r[0]).set == CSD::DECSpecialGraphics );
    }
    SECTION( "ESC ( A" ) {
        auto r = parser.Parse(to_bytes("\x1B""(A"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::designate_character_set );
        CHECK( as_character_set_designation(r[0]).target == 0 );
        CHECK( as_character_set_designation(r[0]).set == CSD::UK );
    }
    SECTION( "ESC ( B" ) {
        auto r = parser.Parse(to_bytes("\x1B""(B"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::designate_character_set );
        CHECK( as_character_set_designation(r[0]).target == 0 );
        CHECK( as_character_set_designation(r[0]).set == CSD::USASCII );
    }
    SECTION( "ESC ( 1" ) {
        auto r = parser.Parse(to_bytes("\x1B""(1"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::designate_character_set );
        CHECK( as_character_set_designation(r[0]).target == 0 );
        CHECK( as_character_set_designation(r[0]).set ==
              CSD::AlternateCharacterROMStandardCharacters );
    }
    SECTION( "ESC ( 2" ) {
        auto r = parser.Parse(to_bytes("\x1B""(2"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::designate_character_set );
        CHECK( as_character_set_designation(r[0]).target == 0 );
        CHECK( as_character_set_designation(r[0]).set ==
              CSD::AlternateCharacterROMSpecialGraphics );
    }
    SECTION( "ESC ) 0" ) {
        auto r = parser.Parse(to_bytes("\x1B"")0"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::designate_character_set );
        CHECK( as_character_set_designation(r[0]).target == 1 );
        CHECK( as_character_set_designation(r[0]).set == CSD::DECSpecialGraphics );
    }
    SECTION( "ESC * 0" ) {
        auto r = parser.Parse(to_bytes("\x1B""*0"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::designate_character_set );
        CHECK( as_character_set_designation(r[0]).target == 2 );
        CHECK( as_character_set_designation(r[0]).set == CSD::DECSpecialGraphics );
    }
    SECTION( "ESC + 0" ) {
        auto r = parser.Parse(to_bytes("\x1B""+0"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::designate_character_set );
        CHECK( as_character_set_designation(r[0]).target == 3 );
        CHECK( as_character_set_designation(r[0]).set == CSD::DECSpecialGraphics );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}

TEST_CASE(PREFIX"CSIParamsScanner")
{
    using S = Parser2Impl::CSIParamsScanner;
    SECTION("") {
        auto p = S::Parse("");
        CHECK(p.count == 0); 
    }
    SECTION("A") {
        auto p = S::Parse("A");
        CHECK(p.count == 0); 
    }
    SECTION("A11") {
        auto p = S::Parse("A");
        CHECK(p.count == 0); 
    }    
    SECTION("39A") {
        auto p = S::Parse("39A");
        CHECK(p.count == 1); 
        CHECK(p.values[0] == 39);
    }
    SECTION(";39A") {
        auto p = S::Parse(";39A");
        CHECK(p.count == 2);
        CHECK(p.values[0] == 0);
        CHECK(p.values[1] == 39);
    }
    SECTION("39;13A") {
        auto p = S::Parse("39;13A");
        CHECK(p.count == 2); 
        CHECK(p.values[0] == 39);
        CHECK(p.values[1] == 13);
    }
    SECTION("39;13A") {
        auto p = S::Parse("39;13A");
        CHECK(p.count == 2); 
        CHECK(p.values[0] == 39);
        CHECK(p.values[1] == 13);
    }
    SECTION("0;1;2;3;4;5;6;7;8;9;10A") {
        auto p = S::Parse("0;1;2;3;4;5;6;7;8;9;10A");
        CHECK(p.count == S::MaxParams); 
        for( int i = 0; i != S::MaxParams; ++i)
            CHECK(p.values[i] == i);
    }       
    SECTION("99999999999999999999999999999999999") {
        auto p = S::Parse("99999999999999999999999999999999999");
        CHECK(p.count == 0); 
    }
    SECTION("7;99999999999999999999999999999999999") {
        auto p = S::Parse("7;99999999999999999999999999999999999");
        CHECK(p.count == 1);
        CHECK(p.values[0] == 7); 
    }           
}

TEST_CASE(PREFIX"Properly handles torn sequences")
{
    Parser2Impl parser;
    SECTION( "ESC [ 34 P" ) {
        auto r1 = parser.Parse(to_bytes("\x1B"));
        REQUIRE( r1.size() == 0 );
        auto r2 = parser.Parse(to_bytes("[34P"));
        REQUIRE( r2.size() == 1 );
        CHECK( r2[0].type == Type::delete_characters );
        CHECK( as_unsigned(r2[0]) == 34 );
    }
    SECTION( "\xf0\x9f\x98\xb1" ) { // 😱
        auto r1 = parser.Parse(to_bytes("\xf0\x9f"));
        REQUIRE( r1.size() == 0 );
        auto r2 = parser.Parse(to_bytes("\x98\xb1\xf0\x9f\x98"));
        REQUIRE( r2.size() == 1 );
        CHECK( r2[0].type == Type::text );
        CHECK( as_utf8text(r2[0]).characters == "\xf0\x9f\x98\xb1" );
        auto r3 = parser.Parse(to_bytes("\xb1"));
        REQUIRE( r3.size() == 1 );
        CHECK( r3[0].type == Type::text );
        CHECK( as_utf8text(r3[0]).characters == "\xf0\x9f\x98\xb1" );
    }
    CHECK( parser.GetEscState() == Parser2Impl::EscState::Text );
}
