// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Interpreter.h"
#include "Screen.h"
#include <bitset>

namespace nc::term {

class InterpreterImpl : public Interpreter
{
public:
    InterpreterImpl(Screen &_screen);
    ~InterpreterImpl() override;
    
    void Interpret( Input _to_interpret ) override;
    void SetOuput( Output _output ) override;
    
private:
    using TabStops = std::bitset<1024>;
    static void ResetToDefaultTabStops(TabStops &_tab_stops); 
    void ProcessText( const input::UTF8Text &_text );
    void ProcessLF();
    void ProcessCR();
    void ProcessBS();
    void ProcessRI();
    void ProcessMC( input::CursorMovement _cursor_movement );
    void ProcessHT( signed _amount );
    void ProcessTerminalId();
    void Response(std::string_view _text);

    struct Extent {
        int height = 0;  // physical dimention - x
        int width = 0;   // physical dimention - y
        int top = 0;     // logical bounds - top
        int bottom = 0;  // logical bounds - bottom
    };

    Screen &m_Screen;
    Output m_Output;
    Extent m_Extent;
    TabStops m_TabStops;
};

}
