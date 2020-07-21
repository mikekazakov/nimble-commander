// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Interpreter.h"
#include "Screen.h"
#include "ScreenBuffer.h"
#include <bitset>
#include <optional>

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
    void ProcessDesignateCharacterSet( input::CharacterSetDesignation _designation );
    void ProcessSelectCharacterSet( unsigned _target );
    void ProcessSaveState();
    void ProcessRestoreState();
    void ProcessInsertLines( unsigned _lines );
    void ProcessDeleteLines( unsigned _lines );
    void ProcessDeleteCharacters( unsigned _characters );
    void ProcessInsertCharacters( unsigned _characters );
    void Response(std::string_view _text);
    void UpdateCharacterAttributes();
    
    struct Extent {
        int height = 0;  // physical dimention - x
        int width = 0;   // physical dimention - y
        int top = 0;     // logical bounds - top, closed [
        int bottom = 0;  // logical bounds - bottom, open )
    };
    
    struct CharacterSets {
        std::array<unsigned, 4> Gx = {0, 0, 0, 0};
    };
    
    struct Rendition {
        bool faint = false;
        bool inverse = false;
        bool bold = false;
        bool italic = false;
        bool invisible = false;
        bool blink = false;
        bool underline = false;
        std::uint8_t fg_color = ScreenColors::Default;
        std::uint8_t bg_color = ScreenColors::Default;
    };
    
    struct SavedState {
        int x = 0;
        int y = 0;
        Rendition rendition;
        CharacterSets character_sets;
        const unsigned short *translate_map = nullptr;
    };

    Screen &m_Screen;
    Output m_Output = [](Bytes){};
    Bell m_Bell = []{};
    Extent m_Extent;
    TabStops m_TabStops;
    const unsigned short *m_TranslateMap = nullptr;
    CharacterSets m_CS;
    bool m_OriginLineMode = false;
    bool m_AllowScreenResize = true;
    bool m_AutoWrapMode = true;
    bool m_InsertMode = false;
    Rendition m_Rendition;
    std::optional<SavedState> m_SavedState;
};

}
