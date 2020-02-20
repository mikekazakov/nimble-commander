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
        static_cast<long>(std::string_view(_characters).size()) };
}

static Parser2::Bytes to_bytes(const char8_t *_characters)
{
    assert( _characters != nullptr );
    return Parser2::Bytes{ reinterpret_cast<const std::byte*>(_characters),
        static_cast<long>(std::u8string_view{_characters}.size())
    };
}

static const UTF32Text& as_utf32text( const Command &_command )
{
    if( auto ptr = std::get_if<UTF32Text>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not UTF32Text");
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

static const TabsAmount& as_tabs_mount( const Command &_command )
{
    if( auto ptr = std::get_if<TabsAmount>(&_command.payload) )
        return *ptr;
    throw std::invalid_argument("not TabsAmount");
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
        CHECK( as_utf32text(r[0]).characters == U"t" );
    }
    SECTION( "Two characters" ) {
        auto r = parser.Parse(to_bytes("qp"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::text );
        CHECK( as_utf32text(r[0]).characters == U"qp" );
    }
    SECTION( "Multiple characters" ) {
        auto r = parser.Parse(to_bytes("Hello, World!"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::text );
        CHECK( as_utf32text(r[0]).characters == U"Hello, World!" ); 
    }
    SECTION( "Multiple characters" ) {
        auto r = parser.Parse(to_bytes("Hello, World!"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::text );
        CHECK( as_utf32text(r[0]).characters == U"Hello, World!" ); 
    }
    SECTION("Smile") {
        auto r = parser.Parse(to_bytes(u8"🤩"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::text );
        CHECK( as_utf32text(r[0]).characters == U"🤩" );
    }
    SECTION("Variable length") {
        auto r = parser.Parse(to_bytes(u8"This is какая-то смесь языков 😱!"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::text );
        CHECK( as_utf32text(r[0]).characters == U"This is какая-то смесь языков 😱!" );        
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
        CHECK( as_tabs_mount(r[0]).amount == 1 );
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
    SECTION( "ESC E" ) {
        auto r = parser.Parse(to_bytes("\x1B""E"));
        REQUIRE( r.size() == 2 );
        CHECK( r[0].type == Type::carriage_return );
        CHECK( r[1].type == Type::line_feed );
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
    SECTION( "ESC [ 42 C" ) {
        auto r = parser.Parse(to_bytes("\x1B""[42C"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::move_cursor );
        CHECK( as_cursor_movement(r[0]).positioning == CursorMovement::Relative );
        CHECK( as_cursor_movement(r[0]).x == 42 );
        CHECK( as_cursor_movement(r[0]).y == 0 );     
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
        CHECK( as_tabs_mount(r[0]).amount == 1 );
    }
    SECTION( "ESC [ 123 I" ) {
        auto r = parser.Parse(to_bytes("\x1B""[123I"));
        REQUIRE( r.size() == 1 );
        CHECK( r[0].type == Type::horizontal_tab );
        CHECK( as_tabs_mount(r[0]).amount == 123 );
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