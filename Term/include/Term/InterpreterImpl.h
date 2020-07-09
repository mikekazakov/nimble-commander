// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Interpreter.h"
#include "Screen.h"
#include "ScreenBuffer.h"
#include <bitset>

namespace nc::term {

class InterpreterImpl : public Interpreter
{
public:
    InterpreterImpl(Screen &_screen);
    ~InterpreterImpl() override;
    
    void Interpret( Input _to_interpret ) override;
    void Interpret( const input::Command& _command );
    void SetOuput( Output _output ) override;
    void SetBell( Bell _bell ) override;
    bool ScreenResizeAllowed() override;
    void SetScreenResizeAllowed( bool _allow ) override;
    
private:
    using TabStops = std::bitset<1024>;
    static void ResetToDefaultTabStops(TabStops &_tab_stops);
    void InterpretSingleCommand( const input::Command& _command );
    void ProcessText( const input::UTF8Text &_text );
    void ProcessLF();
    void ProcessCR();
    void ProcessBS();
    void ProcessRI();
    void ProcessMC( input::CursorMovement _cursor_movement );
    void ProcessHT( signed _amount );
    void ProcessHTS();
    void ProcessReport( input::DeviceReport _device_report );
    void ProcessBell();
    void ProcessScreenAlignment();
    void ProcessEraseInDisplay( input::DisplayErasure _display_erasure );
    void ProcessEraseInLine( input::LineErasure _line_erasure );
    void ProcessSetScrollingRegion( input::ScrollingRegion _scrolling_region );
    void ProcessChangeMode( input::ModeChange _mode_change );
    void ProcessChangeColumnMode132( bool _on );
    void ProcessClearTab( input::TabClear _tab_clear );
    void ProcessSetCharacterAttributes( input::CharacterAttributes _attributes );
    void Response(std::string_view _text);
    void UpdateCharacterAttributes();
    
    struct Extent {
        int height = 0;  // physical dimention - x
        int width = 0;   // physical dimention - y
        int top = 0;     // logical bounds - top, closed [
        int bottom = 0;  // logical bounds - bottom, open )
    };

    Screen &m_Screen;
    Output m_Output = [](Bytes){};
    Bell m_Bell = []{};
    Extent m_Extent;
    TabStops m_TabStops;
    bool m_OriginLineMode = false;
    bool m_AllowScreenResize = true;
    bool m_AutoWrapMode = true;
    bool m_Faint = false;
    bool m_Inverse = false;
    std::uint8_t m_FgColor = ScreenColors::Default;
    std::uint8_t m_BgColor = ScreenColors::Default;
};

}
