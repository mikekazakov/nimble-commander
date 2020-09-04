// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <InterpreterImpl.h>
#include "Tests.h"

using namespace nc::term;
using namespace nc::term::input;
#define PREFIX "nc::term::Interpreter "

TEST_CASE(PREFIX"does call the Bell callback")
{        
    Screen screen(10, 6);
    InterpreterImpl interpreter(screen);
    bool did_bell = false;
    interpreter.SetBell([&]{ did_bell = true; });

    const Command cmd{input::Type::bell};
    interpreter.Interpret( {&cmd, 1} );
    CHECK( did_bell == true ); 
}

TEST_CASE(PREFIX"resizes screen only when allowed")
{
    Screen screen(10, 6);
    InterpreterImpl interpreter(screen);
    SECTION("Allowed - default") {
        SECTION("80") {
            const Command cmd{Type::change_mode, ModeChange{ModeChange::Kind::Column132, false}};
            interpreter.Interpret( {&cmd, 1} );
            CHECK( screen.Width() == 80 );
            CHECK( screen.Height() == 6 );
        }
        SECTION("132") {
            const Command cmd{Type::change_mode, ModeChange{ModeChange::Kind::Column132, true}};
            interpreter.Interpret( {&cmd, 1} );
            CHECK( screen.Width() == 132 );
            CHECK( screen.Height() == 6 );
        }
    }
    SECTION("Disabled") {
        interpreter.SetScreenResizeAllowed(false);
        SECTION("80") {
            const Command cmd{Type::change_mode, ModeChange{ModeChange::Kind::Column132, false}};
            interpreter.Interpret( {&cmd, 1} );
        }
        SECTION("132") {
            const Command cmd{Type::change_mode, ModeChange{ModeChange::Kind::Column132, true}};
            interpreter.Interpret( {&cmd, 1} );
        }
        CHECK( screen.Width() == 10 );
        CHECK( screen.Height() == 6 );
    }
}

TEST_CASE(PREFIX"setting normal attributes")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Faint}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::ForegroundRed}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::BackgroundBlue}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Inverse}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Bold}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Italicized}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Invisible}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Blink}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Underlined}));
    
    interpreter.Interpret(Command(Type::set_character_attributes, CA{CA::Normal}));
    interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
    
    const auto c = screen.Buffer().At(0, 0);
    CHECK( c.foreground == ScreenColors::Default );
    CHECK( c.background == ScreenColors::Default );
    CHECK( c.faint == false );
    CHECK( c.reverse == false );
    CHECK( c.bold == false );
    CHECK( c.italic == false );
    CHECK( c.invisible == false );
    CHECK( c.blink == false );
    CHECK( c.underline == false );
}

TEST_CASE(PREFIX"setting foreground colors")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, std::uint8_t _color) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).foreground == _color );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).foreground == ScreenColors::Default );
    }
    SECTION("Black") {
        verify(CA::ForegroundBlack, ScreenColors::Black);
    }
    SECTION("Red") {
        verify(CA::ForegroundRed, ScreenColors::Red);
    }
    SECTION("Green") {
        verify(CA::ForegroundGreen, ScreenColors::Green);
    }
    SECTION("Yellow") {
        verify(CA::ForegroundYellow, ScreenColors::Yellow);
    }
    SECTION("Blue") {
        verify(CA::ForegroundBlue, ScreenColors::Blue);
    }
    SECTION("Magenta") {
        verify(CA::ForegroundMagenta, ScreenColors::Magenta);
    }
    SECTION("Cyan") {
        verify(CA::ForegroundCyan, ScreenColors::Cyan);
    }
    SECTION("White") {
        verify(CA::ForegroundWhite, ScreenColors::White);
    }
    SECTION("BlackBright") {
        verify(CA::ForegroundBlackBright, ScreenColors::BlackHi);
    }
    SECTION("RedBright") {
        verify(CA::ForegroundRedBright, ScreenColors::RedHi);
    }
    SECTION("GreenBright") {
        verify(CA::ForegroundGreenBright, ScreenColors::GreenHi);
    }
    SECTION("YellowBright") {
        verify(CA::ForegroundYellowBright, ScreenColors::YellowHi);
    }
    SECTION("BlueBright") {
        verify(CA::ForegroundBlueBright, ScreenColors::BlueHi);
    }
    SECTION("MagentaBright") {
        verify(CA::ForegroundMagentaBright, ScreenColors::MagentaHi);
    }
    SECTION("CyanBright") {
        verify(CA::ForegroundCyanBright, ScreenColors::CyanHi);
    }
    SECTION("WhiteBright") {
        verify(CA::ForegroundWhiteBright, ScreenColors::WhiteHi);
    }
    SECTION("Default") {
        verify(CA::ForegroundDefault, ScreenColors::Default);
    }
}

TEST_CASE(PREFIX"setting background colors")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, std::uint8_t _color) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).background == _color );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).background == ScreenColors::Default );
    }
    SECTION("Black") {
        verify(CA::BackgroundBlack, ScreenColors::Black);
    }
    SECTION("Red") {
        verify(CA::BackgroundRed, ScreenColors::Red);
    }
    SECTION("Green") {
        verify(CA::BackgroundGreen, ScreenColors::Green);
    }
    SECTION("Yellow") {
        verify(CA::BackgroundYellow, ScreenColors::Yellow);
    }
    SECTION("Blue") {
        verify(CA::BackgroundBlue, ScreenColors::Blue);
    }
    SECTION("Magenta") {
        verify(CA::BackgroundMagenta, ScreenColors::Magenta);
    }
    SECTION("Cyan") {
        verify(CA::BackgroundCyan, ScreenColors::Cyan);
    }
    SECTION("White") {
        verify(CA::BackgroundWhite, ScreenColors::White);
    }    
    SECTION("BlackBright") {
        verify(CA::BackgroundBlackBright, ScreenColors::BlackHi);
    }
    SECTION("RedBright") {
        verify(CA::BackgroundRedBright, ScreenColors::RedHi);
    }
    SECTION("GreenBright") {
        verify(CA::BackgroundGreenBright, ScreenColors::GreenHi);
    }
    SECTION("YellowBright") {
        verify(CA::BackgroundYellowBright, ScreenColors::YellowHi);
    }
    SECTION("BlueBright") {
        verify(CA::BackgroundBlueBright, ScreenColors::BlueHi);
    }
    SECTION("MagentaBright") {
        verify(CA::BackgroundMagentaBright, ScreenColors::MagentaHi);
    }
    SECTION("CyanBright") {
        verify(CA::BackgroundCyanBright, ScreenColors::CyanHi);
    }
    SECTION("WhiteBright") {
        verify(CA::BackgroundWhiteBright, ScreenColors::WhiteHi);
    }
    SECTION("Default") {
        verify(CA::BackgroundDefault, ScreenColors::Default);
    }
}

TEST_CASE(PREFIX"setting faint")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _faint) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).faint == _faint );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).faint == false );
    }
    SECTION("Normal") {
        verify(CA::Normal, false);
    }
    SECTION("Faint") {
        verify(CA::Faint, true);
    }
    SECTION("Not Bold Not Faint") {
        verify(CA::NotBoldNotFaint, false);
    }
}

TEST_CASE(PREFIX"setting inverse")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _inverse) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).reverse == _inverse );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).reverse == false );
    }
    SECTION("Inverse") {
        verify(CA::Inverse, true);
    }
    SECTION("Not inverse") {
        verify(CA::NotInverse, false);
    }
}

TEST_CASE(PREFIX"setting bold")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _bold) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).bold == _bold );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).bold == false );
    }
    SECTION("Bold") {
        verify(CA::Bold, true);
    }
    SECTION("Not bold") {
        verify(CA::NotBoldNotFaint, false);
    }
}

TEST_CASE(PREFIX"setting italic")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _italic) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).italic == _italic );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).italic == false );
    }
    SECTION("Italic") {
        verify(CA::Italicized, true);
    }
    SECTION("Not italic") {
        verify(CA::NotItalicized, false);
    }
}

TEST_CASE(PREFIX"setting invisible")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _invisible) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).invisible == _invisible );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).invisible == false );
    }
    SECTION("Invisible") {
        verify(CA::Invisible, true);
    }
    SECTION("Not invsible") {
        verify(CA::NotInvisible, false);
    }
}

TEST_CASE(PREFIX"setting blink")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _blink) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).blink == _blink );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).blink == false );
    }
    SECTION("Blink") {
        verify(CA::Blink, true);
    }
    SECTION("Not blink") {
        verify(CA::NotBlink, false);
    }
}

TEST_CASE(PREFIX"setting underline")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _underline) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{_kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).underline == _underline );
    };
    SECTION("Implicit") {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK( screen.Buffer().At(0, 0).underline == false );
    }
    SECTION("Underline") {
        verify(CA::Underlined, true);
    }
    SECTION("Doubly Underline") {
        verify(CA::DoublyUnderlined, true);
    }
    SECTION("Not underlined") {
        verify(CA::NotUnderlined, false);
    }
}

TEST_CASE(PREFIX"G0 - DEC Special Graphics")
{
    using namespace input;
    using CSD = CharacterSetDesignation;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    SECTION("Graph") {
        interpreter.Interpret(Command(Type::designate_character_set,
                                      CSD{ 0, CSD::DECSpecialGraphics }));
        interpreter.Interpret(Command(Type::text, UTF8Text{"n"}));
        CHECK( screen.Buffer().At(0, 0).l == U'┼' );
    }
    SECTION("Graph and back") {
        interpreter.Interpret(Command(Type::designate_character_set,
                                      CSD{ 0, CSD::USASCII }));
        interpreter.Interpret(Command(Type::text, UTF8Text{"n"}));
        CHECK( screen.Buffer().At(0, 0).l == 'n' );
    }
}

TEST_CASE(PREFIX"Save/restore")
{
    using namespace input;
    Screen screen(2, 2);
    InterpreterImpl interpreter(screen);
    SECTION("Coordinates") {
        interpreter.Interpret(Command{Type::save_state});
        interpreter.Interpret(Command(Type::move_cursor,
                                      CursorMovement{CursorMovement::Absolute, 1, 1}));
        interpreter.Interpret(Command{Type::restore_state});
        CHECK(screen.CursorX() == 0);
        CHECK(screen.CursorY() == 0);
    }
    SECTION("Rendition") {
        using CA = CharacterAttributes;
        const auto sca = Type::set_character_attributes;
        interpreter.Interpret(Command{Type::save_state});
        interpreter.Interpret(Command(sca, CA{CA::ForegroundRed}));
        interpreter.Interpret(Command(sca, CA{CA::BackgroundBlue}));
        interpreter.Interpret(Command(sca, CA{CA::Faint}));
        interpreter.Interpret(Command(sca, CA{CA::Bold}));
        interpreter.Interpret(Command(sca, CA{CA::Italicized}));
        interpreter.Interpret(Command(sca, CA{CA::Blink}));
        interpreter.Interpret(Command(sca, CA{CA::Inverse}));
        interpreter.Interpret(Command(sca, CA{CA::Invisible}));
        interpreter.Interpret(Command(sca, CA{CA::Underlined}));
        interpreter.Interpret(Command{Type::restore_state});
        interpreter.Interpret(Command(Type::text, UTF8Text{"a"}));
        const auto sp = screen.Buffer().At(0, 0);
        CHECK( sp.foreground == ScreenColors::Default );
        CHECK( sp.background == ScreenColors::Default );
        CHECK( sp.faint == false );
        CHECK( sp.bold == false );
        CHECK( sp.italic == false );
        CHECK( sp.blink == false );
        CHECK( sp.reverse == false );
        CHECK( sp.invisible == false );
        CHECK( sp.underline == false );
    }
    SECTION("Character set") {
        using CSD = CharacterSetDesignation;
        interpreter.Interpret(Command{Type::save_state});
        interpreter.Interpret(Command(Type::designate_character_set,
                                      CSD{ 0, CSD::DECSpecialGraphics }));
        interpreter.Interpret(Command{Type::restore_state});
        interpreter.Interpret(Command(Type::text, UTF8Text{"n"}));
        CHECK( screen.Buffer().At(0, 0).l == 'n' );
    }
}

TEST_CASE(PREFIX"Change title")
{
    using namespace input;
    Screen screen(2, 2);
    InterpreterImpl interpreter(screen);
    
    std::string title;
    bool icon = false;
    bool window = false;
    auto callback = [&](const std::string& _title, bool _icon, bool _window) {
        title = _title;
        icon = _icon;
        window = _window;
    };
    interpreter.SetTitle( callback );

    SECTION( "IconAndWindow" ) {
        Title t{Title::IconAndWindow, "Hi1"};
        interpreter.Interpret(Command(Type::change_title, t));
        CHECK(title == "Hi1");
        CHECK(icon == true);
        CHECK(window == true);
    }
    SECTION( "Icon" ) {
        Title t{Title::Icon, "Hi2"};
        interpreter.Interpret(Command(Type::change_title, t));
        CHECK(title == "Hi2");
        CHECK(icon == true);
        CHECK(window == false);
    }
    SECTION( "Window" ) {
        Title t{Title::Window, "Hi3"};
        interpreter.Interpret(Command(Type::change_title, t));
        CHECK(title == "Hi3");
        CHECK(icon == false);
        CHECK(window == true);
    }
}

TEST_CASE(PREFIX"Properly updates internal sizes")
{
    using namespace input;
    Screen screen(2, 2);
    const auto &buffer = screen.Buffer();
    InterpreterImpl interpreter(screen);
    screen.ResizeScreen(3, 3);
    interpreter.NotifyScreenResized();
    interpreter.Interpret(Command(Type::text, UTF8Text{"012"}));
    interpreter.Interpret(Command(Type::text, UTF8Text{"123"}));
    interpreter.Interpret(Command(Type::text, UTF8Text{"234"}));
    interpreter.Interpret(Command(Type::text, UTF8Text{"345"}));
    CHECK( buffer.DumpBackScreenAsANSI() ==
          "012" );
    CHECK( buffer.DumpScreenAsANSI() ==
          "123"
          "234"
          "345" );
}
