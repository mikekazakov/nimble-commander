// Copyright (C) 2020-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include <InterpreterImpl.h>
#include <optional>
#include "Tests.h"

using namespace nc::term;
using namespace nc::term::input;
#define PREFIX "nc::term::Interpreter "

TEST_CASE(PREFIX "does call the Bell callback")
{
    Screen screen(10, 6);
    InterpreterImpl interpreter(screen);
    bool did_bell = false;
    interpreter.SetBell([&] { did_bell = true; });

    const Command cmd{input::Type::bell};
    interpreter.Interpret({&cmd, 1});
    CHECK(did_bell == true);
}

TEST_CASE(PREFIX "resizes screen only when allowed")
{
    Screen screen(10, 6);
    InterpreterImpl interpreter(screen);
    SECTION("Allowed - default")
    {
        SECTION("80")
        {
            const Command cmd{Type::change_mode, ModeChange{.mode = ModeChange::Kind::Column132, .status = false}};
            interpreter.Interpret({&cmd, 1});
            CHECK(screen.Width() == 80);
            CHECK(screen.Height() == 6);
        }
        SECTION("132")
        {
            const Command cmd{Type::change_mode, ModeChange{.mode = ModeChange::Kind::Column132, .status = true}};
            interpreter.Interpret({&cmd, 1});
            CHECK(screen.Width() == 132);
            CHECK(screen.Height() == 6);
        }
    }
    SECTION("Disabled")
    {
        interpreter.SetScreenResizeAllowed(false);
        SECTION("80")
        {
            const Command cmd{Type::change_mode, ModeChange{.mode = ModeChange::Kind::Column132, .status = false}};
            interpreter.Interpret({&cmd, 1});
        }
        SECTION("132")
        {
            const Command cmd{Type::change_mode, ModeChange{.mode = ModeChange::Kind::Column132, .status = true}};
            interpreter.Interpret({&cmd, 1});
        }
        CHECK(screen.Width() == 10);
        CHECK(screen.Height() == 6);
    }
}

TEST_CASE(PREFIX "setting normal attributes")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = CA::Faint}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = CA::ForegroundColor}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = CA::BackgroundColor}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = CA::Inverse}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = CA::Bold}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = CA::Italicized}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = CA::Invisible}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = CA::Blink}));
    interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = CA::Underlined}));

    interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = CA::Normal}));
    interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));

    const auto c = screen.Buffer().At(0, 0);
    CHECK(c.customfg == false);
    CHECK(c.custombg == false);
    CHECK(c.faint == false);
    CHECK(c.reverse == false);
    CHECK(c.bold == false);
    CHECK(c.italic == false);
    CHECK(c.invisible == false);
    CHECK(c.blink == false);
    CHECK(c.underline == false);
}

TEST_CASE(PREFIX "setting foreground colors")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](std::optional<Color> _color) {
        interpreter.Interpret(
            Command(Type::set_character_attributes,
                    _color ? CA{.mode = CA::ForegroundColor, .color = *_color} : CA{.mode = CA::ForegroundDefault}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).foreground == (_color ? *_color : Color{}));
        CHECK(screen.Buffer().At(0, 0).customfg == static_cast<bool>(_color));
    };
    SECTION("Implicit")
    {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).foreground == Color{});
        CHECK(screen.Buffer().At(0, 0).customfg == false);
    }
    SECTION("Black")
    {
        verify(Color::Black);
    }
    SECTION("Red")
    {
        verify(Color::Red);
    }
    SECTION("Green")
    {
        verify(Color::Green);
    }
    SECTION("Yellow")
    {
        verify(Color::Yellow);
    }
    SECTION("Blue")
    {
        verify(Color::Blue);
    }
    SECTION("Magenta")
    {
        verify(Color::Magenta);
    }
    SECTION("Cyan")
    {
        verify(Color::Cyan);
    }
    SECTION("White")
    {
        verify(Color::White);
    }
    SECTION("BlackBright")
    {
        verify(Color::BrightBlack);
    }
    SECTION("RedBright")
    {
        verify(Color::BrightRed);
    }
    SECTION("GreenBright")
    {
        verify(Color::BrightGreen);
    }
    SECTION("YellowBright")
    {
        verify(Color::BrightYellow);
    }
    SECTION("BlueBright")
    {
        verify(Color::BrightBlue);
    }
    SECTION("MagentaBright")
    {
        verify(Color::BrightMagenta);
    }
    SECTION("CyanBright")
    {
        verify(Color::BrightCyan);
    }
    SECTION("WhiteBright")
    {
        verify(Color::BrightWhite);
    }
    SECTION("Default")
    {
        verify(std::nullopt);
    }
    // TODO: 8-bit colors
}

TEST_CASE(PREFIX "setting background colors")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](std::optional<Color> _color) {
        interpreter.Interpret(
            Command(Type::set_character_attributes,
                    _color ? CA{.mode = CA::BackgroundColor, .color = *_color} : CA{.mode = CA::BackgroundDefault}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).background == (_color ? *_color : Color{}));
        CHECK(screen.Buffer().At(0, 0).custombg == static_cast<bool>(_color));
    };
    SECTION("Implicit")
    {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).background == Color{});
        CHECK(screen.Buffer().At(0, 0).custombg == false);
    }
    SECTION("Black")
    {
        verify(Color::Black);
    }
    SECTION("Red")
    {
        verify(Color::Red);
    }
    SECTION("Green")
    {
        verify(Color::Green);
    }
    SECTION("Yellow")
    {
        verify(Color::Yellow);
    }
    SECTION("Blue")
    {
        verify(Color::Blue);
    }
    SECTION("Magenta")
    {
        verify(Color::Magenta);
    }
    SECTION("Cyan")
    {
        verify(Color::Cyan);
    }
    SECTION("White")
    {
        verify(Color::White);
    }
    SECTION("BlackBright")
    {
        verify(Color::BrightBlack);
    }
    SECTION("RedBright")
    {
        verify(Color::BrightRed);
    }
    SECTION("GreenBright")
    {
        verify(Color::BrightGreen);
    }
    SECTION("YellowBright")
    {
        verify(Color::BrightYellow);
    }
    SECTION("BlueBright")
    {
        verify(Color::BrightBlue);
    }
    SECTION("MagentaBright")
    {
        verify(Color::BrightMagenta);
    }
    SECTION("CyanBright")
    {
        verify(Color::BrightCyan);
    }
    SECTION("WhiteBright")
    {
        verify(Color::BrightWhite);
    }
    SECTION("Default")
    {
        verify(std::nullopt);
    }
    // TODO: 8-bit colors
}

TEST_CASE(PREFIX "setting faint")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _faint) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = _kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).faint == _faint);
    };
    SECTION("Implicit")
    {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).faint == false);
    }
    SECTION("Normal")
    {
        verify(CA::Normal, false);
    }
    SECTION("Faint")
    {
        verify(CA::Faint, true);
    }
    SECTION("Not Bold Not Faint")
    {
        verify(CA::NotBoldNotFaint, false);
    }
}

TEST_CASE(PREFIX "setting inverse")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _inverse) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = _kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).reverse == _inverse);
    };
    SECTION("Implicit")
    {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).reverse == false);
    }
    SECTION("Inverse")
    {
        verify(CA::Inverse, true);
    }
    SECTION("Not inverse")
    {
        verify(CA::NotInverse, false);
    }
}

TEST_CASE(PREFIX "setting bold")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _bold) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = _kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).bold == _bold);
    };
    SECTION("Implicit")
    {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).bold == false);
    }
    SECTION("Bold")
    {
        verify(CA::Bold, true);
    }
    SECTION("Not bold")
    {
        verify(CA::NotBoldNotFaint, false);
    }
}

TEST_CASE(PREFIX "setting italic")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _italic) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = _kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).italic == _italic);
    };
    SECTION("Implicit")
    {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).italic == false);
    }
    SECTION("Italic")
    {
        verify(CA::Italicized, true);
    }
    SECTION("Not italic")
    {
        verify(CA::NotItalicized, false);
    }
}

TEST_CASE(PREFIX "setting invisible")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _invisible) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = _kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).invisible == _invisible);
    };
    SECTION("Implicit")
    {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).invisible == false);
    }
    SECTION("Invisible")
    {
        verify(CA::Invisible, true);
    }
    SECTION("Not invsible")
    {
        verify(CA::NotInvisible, false);
    }
}

TEST_CASE(PREFIX "setting blink")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _blink) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = _kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).blink == _blink);
    };
    SECTION("Implicit")
    {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).blink == false);
    }
    SECTION("Blink")
    {
        verify(CA::Blink, true);
    }
    SECTION("Not blink")
    {
        verify(CA::NotBlink, false);
    }
}

TEST_CASE(PREFIX "setting underline")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _underline) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = _kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).underline == _underline);
    };
    SECTION("Implicit")
    {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).underline == false);
    }
    SECTION("Underline")
    {
        verify(CA::Underlined, true);
    }
    SECTION("Doubly Underline")
    {
        verify(CA::DoublyUnderlined, true);
    }
    SECTION("Not underlined")
    {
        verify(CA::NotUnderlined, false);
    }
}

TEST_CASE(PREFIX "setting crossed")
{
    using namespace input;
    using CA = input::CharacterAttributes;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    auto verify = [&](CA::Kind _kind, bool _crossed) {
        interpreter.Interpret(Command(Type::set_character_attributes, CA{.mode = _kind}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).crossed == _crossed);
    };
    SECTION("Implicit")
    {
        interpreter.Interpret(Command(Type::text, UTF8Text{"A"}));
        CHECK(screen.Buffer().At(0, 0).crossed == false);
    }
    SECTION("Crossed")
    {
        verify(CA::Crossed, true);
    }
    SECTION("Not crossed")
    {
        verify(CA::NotCrossed, false);
    }
}

TEST_CASE(PREFIX "G0 - DEC Special Graphics")
{
    using namespace input;
    using CSD = CharacterSetDesignation;
    Screen screen(1, 1);
    InterpreterImpl interpreter(screen);
    SECTION("Graph")
    {
        interpreter.Interpret(Command(Type::designate_character_set, CSD{0, CSD::DECSpecialGraphics}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"n"}));
        CHECK(screen.Buffer().At(0, 0).l == U'┼');
    }
    SECTION("Graph and back")
    {
        interpreter.Interpret(Command(Type::designate_character_set, CSD{0, CSD::USASCII}));
        interpreter.Interpret(Command(Type::text, UTF8Text{"n"}));
        CHECK(screen.Buffer().At(0, 0).l == 'n');
    }
}

TEST_CASE(PREFIX "Save/restore")
{
    using namespace input;
    Screen screen(2, 2);
    InterpreterImpl interpreter(screen);
    SECTION("Coordinates")
    {
        interpreter.Interpret(Command{Type::save_state});
        interpreter.Interpret(
            Command(Type::move_cursor, CursorMovement{.positioning = CursorMovement::Absolute, .x = 1, .y = 1}));
        interpreter.Interpret(Command{Type::restore_state});
        CHECK(screen.CursorX() == 0);
        CHECK(screen.CursorY() == 0);
    }
    SECTION("Rendition")
    {
        using CA = CharacterAttributes;
        const auto sca = Type::set_character_attributes;
        interpreter.Interpret(Command{Type::save_state});
        interpreter.Interpret(Command(sca, CA{.mode = CA::ForegroundColor, .color = Color::Red}));
        interpreter.Interpret(Command(sca, CA{.mode = CA::BackgroundColor, .color = Color::Blue}));
        interpreter.Interpret(Command(sca, CA{.mode = CA::Faint}));
        interpreter.Interpret(Command(sca, CA{.mode = CA::Bold}));
        interpreter.Interpret(Command(sca, CA{.mode = CA::Italicized}));
        interpreter.Interpret(Command(sca, CA{.mode = CA::Blink}));
        interpreter.Interpret(Command(sca, CA{.mode = CA::Inverse}));
        interpreter.Interpret(Command(sca, CA{.mode = CA::Invisible}));
        interpreter.Interpret(Command(sca, CA{.mode = CA::Underlined}));
        interpreter.Interpret(Command{Type::restore_state});
        interpreter.Interpret(Command(Type::text, UTF8Text{"a"}));
        const auto sp = screen.Buffer().At(0, 0);
        CHECK(sp.foreground == Color{});
        CHECK(sp.background == Color{});
        CHECK(sp.customfg == false);
        CHECK(sp.custombg == false);
        CHECK(sp.faint == false);
        CHECK(sp.bold == false);
        CHECK(sp.italic == false);
        CHECK(sp.blink == false);
        CHECK(sp.reverse == false);
        CHECK(sp.invisible == false);
        CHECK(sp.underline == false);
    }
    SECTION("Character set")
    {
        using CSD = CharacterSetDesignation;
        interpreter.Interpret(Command{Type::save_state});
        interpreter.Interpret(Command(Type::designate_character_set, CSD{0, CSD::DECSpecialGraphics}));
        interpreter.Interpret(Command{Type::restore_state});
        interpreter.Interpret(Command(Type::text, UTF8Text{"n"}));
        CHECK(screen.Buffer().At(0, 0).l == 'n');
    }
}

TEST_CASE(PREFIX "Change title")
{
    using namespace input;
    Screen screen(2, 2);
    InterpreterImpl interpreter(screen);

    std::vector<std::string> title;
    std::vector<Interpreter::TitleKind> kind;
    auto callback = [&](const std::string &_title, Interpreter::TitleKind _kind) {
        title.emplace_back(_title);
        kind.emplace_back(_kind);
    };
    interpreter.SetTitle(callback);

    SECTION("IconAndWindow")
    {
        Title t{.kind = Title::IconAndWindow, .title = "Hi1"};
        interpreter.Interpret(Command(Type::change_title, t));
        REQUIRE(title.size() == 2);
        CHECK(title[0] == "Hi1");
        CHECK(title[1] == "Hi1");
        REQUIRE(kind.size() == 2);
        CHECK(kind[0] == Interpreter::TitleKind::Icon);
        CHECK(kind[1] == Interpreter::TitleKind::Window);
    }
    SECTION("Icon")
    {
        Title t{.kind = Title::Icon, .title = "Hi2"};
        interpreter.Interpret(Command(Type::change_title, t));
        REQUIRE(title.size() == 1);
        CHECK(title[0] == "Hi2");
        REQUIRE(kind.size() == 1);
        CHECK(kind[0] == Interpreter::TitleKind::Icon);
    }
    SECTION("Window")
    {
        Title t{.kind = Title::Window, .title = "Hi3"};
        interpreter.Interpret(Command(Type::change_title, t));
        REQUIRE(title.size() == 1);
        CHECK(title[0] == "Hi3");
        REQUIRE(kind.size() == 1);
        CHECK(kind[0] == Interpreter::TitleKind::Window);
    }
    SECTION("Called only on actual changes")
    {
        interpreter.Interpret(Command(Type::change_title, Title{.kind = Title::Window, .title = "A"}));
        REQUIRE(title.size() == 1);
        interpreter.Interpret(Command(Type::change_title, Title{.kind = Title::Window, .title = "A"}));
        REQUIRE(title.size() == 1);
        interpreter.Interpret(Command(Type::change_title, Title{.kind = Title::Icon, .title = "A"}));
        REQUIRE(title.size() == 2);
        interpreter.Interpret(Command(Type::change_title, Title{.kind = Title::Icon, .title = "A"}));
        REQUIRE(title.size() == 2);
        interpreter.Interpret(Command(Type::change_title, Title{.kind = Title::IconAndWindow, .title = "A"}));
        REQUIRE(title.size() == 2);
        interpreter.Interpret(Command(Type::change_title, Title{.kind = Title::IconAndWindow, .title = "B"}));
        REQUIRE(title.size() == 4);
    }
}

TEST_CASE(PREFIX "Supports saving/restoring titles")
{
    using namespace input;
    Screen screen(2, 2);
    InterpreterImpl interpreter(screen);

    std::vector<std::string> title;
    std::vector<Interpreter::TitleKind> kind;
    auto callback = [&](const std::string &_title, Interpreter::TitleKind _kind) {
        title.emplace_back(_title);
        kind.emplace_back(_kind);
    };
    interpreter.SetTitle(callback);

    SECTION("Save and restore both")
    {
        interpreter.Interpret(Command(Type::change_title, Title{.kind = Title::IconAndWindow, .title = "Cat"}));
        interpreter.Interpret(
            Command(Type::manipulate_title,
                    TitleManipulation{.target = TitleManipulation::Both, .operation = TitleManipulation::Save}));
        interpreter.Interpret(Command(Type::change_title, Title{.kind = Title::IconAndWindow, .title = "Dog"}));
        interpreter.Interpret(
            Command(Type::manipulate_title,
                    TitleManipulation{.target = TitleManipulation::Both, .operation = TitleManipulation::Restore}));
        CHECK(title == std::vector<std::string>{"Cat", "Cat", "Dog", "Dog", "Cat", "Cat"});
        CHECK(kind == std::vector<Interpreter::TitleKind>{Interpreter::TitleKind::Icon,
                                                          Interpreter::TitleKind::Window,
                                                          Interpreter::TitleKind::Icon,
                                                          Interpreter::TitleKind::Window,
                                                          Interpreter::TitleKind::Icon,
                                                          Interpreter::TitleKind::Window});
    }
    SECTION("Restore with no saved titles does nothing")
    {
        interpreter.Interpret(
            Command(Type::manipulate_title,
                    TitleManipulation{.target = TitleManipulation::Both, .operation = TitleManipulation::Restore}));
        CHECK(title.empty());
        CHECK(kind.empty());
    }
    SECTION("Uses a LIFO")
    {
        interpreter.Interpret(Command(Type::change_title, Title{.kind = Title::Icon, .title = "Cat"}));
        interpreter.Interpret(
            Command(Type::manipulate_title,
                    TitleManipulation{.target = TitleManipulation::Icon, .operation = TitleManipulation::Save}));
        interpreter.Interpret(Command(Type::change_title, Title{.kind = Title::Icon, .title = "Dog"}));
        interpreter.Interpret(
            Command(Type::manipulate_title,
                    TitleManipulation{.target = TitleManipulation::Icon, .operation = TitleManipulation::Save}));
        interpreter.Interpret(Command(Type::change_title, Title{.kind = Title::Icon, .title = "Fox"}));
        interpreter.Interpret(
            Command(Type::manipulate_title,
                    TitleManipulation{.target = TitleManipulation::Icon, .operation = TitleManipulation::Restore}));
        interpreter.Interpret(
            Command(Type::manipulate_title,
                    TitleManipulation{.target = TitleManipulation::Icon, .operation = TitleManipulation::Restore}));
        CHECK(title == std::vector<std::string>{"Cat", "Dog", "Fox", "Dog", "Cat"});
        CHECK(kind == std::vector<Interpreter::TitleKind>{Interpreter::TitleKind::Icon,
                                                          Interpreter::TitleKind::Icon,
                                                          Interpreter::TitleKind::Icon,
                                                          Interpreter::TitleKind::Icon,
                                                          Interpreter::TitleKind::Icon});
    }
}

TEST_CASE(PREFIX "Properly updates internal sizes")
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
    CHECK(buffer.DumpBackScreenAsANSI() == "012");
    CHECK(buffer.DumpScreenAsANSI() == "123"
                                       "234"
                                       "345");
}

TEST_CASE(PREFIX "Cursor visibility management")
{
    using namespace input;
    Screen screen(2, 2);
    InterpreterImpl interpreter(screen);

    CHECK(interpreter.ShowCursor() == true);

    std::optional<bool> show;
    interpreter.SetShowCursorChanged([&](bool _show) { show = _show; });
    SECTION("on->on")
    {
        interpreter.Interpret(Command(Type::change_mode, ModeChange{.mode = ModeChange::ShowCursor, .status = true}));
        CHECK(interpreter.ShowCursor() == true);
        REQUIRE(show.has_value() == false);
    }
    SECTION("on->off->off->on")
    {
        interpreter.Interpret(Command(Type::change_mode, ModeChange{.mode = ModeChange::ShowCursor, .status = false}));
        CHECK(interpreter.ShowCursor() == false);
        REQUIRE(show.has_value());
        CHECK(show == false);

        show.reset();
        interpreter.Interpret(Command(Type::change_mode, ModeChange{.mode = ModeChange::ShowCursor, .status = false}));
        CHECK(interpreter.ShowCursor() == false);
        CHECK(show.has_value() == false);

        interpreter.Interpret(Command(Type::change_mode, ModeChange{.mode = ModeChange::ShowCursor, .status = true}));
        CHECK(interpreter.ShowCursor() == true);
        REQUIRE(show.has_value());
        CHECK(show == true);
    }
}

TEST_CASE(PREFIX "Cursor style management")
{
    using namespace input;
    Screen screen(2, 2);
    InterpreterImpl interpreter(screen);

    std::optional<CursorMode> mode;
    interpreter.SetCursorStyleChanged([&](std::optional<CursorMode> _mode) { mode = _mode; });

    SECTION("none")
    {
        interpreter.Interpret(Command(Type::set_cursor_style, CursorStyle{std::nullopt}));
        CHECK(mode.has_value() == false);
    }
    SECTION("SteadyBar")
    {
        interpreter.Interpret(Command(Type::set_cursor_style, CursorStyle{CursorMode::SteadyBar}));
        CHECK(mode == CursorMode::SteadyBar);
    }
}
