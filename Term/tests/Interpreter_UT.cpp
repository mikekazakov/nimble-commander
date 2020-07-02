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
            const Command cmd{Type::change_mode, ModeChange{ModeChange::Kind::ColumnMode132, false}};
            interpreter.Interpret( {&cmd, 1} );
            CHECK( screen.Width() == 80 );
            CHECK( screen.Height() == 6 );
        }
        SECTION("132") {
            const Command cmd{Type::change_mode, ModeChange{ModeChange::Kind::ColumnMode132, true}};
            interpreter.Interpret( {&cmd, 1} );
            CHECK( screen.Width() == 132 );
            CHECK( screen.Height() == 6 );
        }
    }
    SECTION("Disabled") {
        interpreter.SetScreenResizeAllowed(false);
        SECTION("80") {
            const Command cmd{Type::change_mode, ModeChange{ModeChange::Kind::ColumnMode132, false}};
            interpreter.Interpret( {&cmd, 1} );
        }
        SECTION("132") {
            const Command cmd{Type::change_mode, ModeChange{ModeChange::Kind::ColumnMode132, true}};
            interpreter.Interpret( {&cmd, 1} );
        }
        CHECK( screen.Width() == 10 );
        CHECK( screen.Height() == 6 );
    }
}
