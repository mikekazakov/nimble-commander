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

    const input::Command cmd{input::Type::bell};    
    interpreter.Interpret( {&cmd, 1} );
    CHECK( did_bell == true ); 
}
