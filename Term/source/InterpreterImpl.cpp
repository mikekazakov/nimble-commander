// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "InterpreterImpl.h"
#include <Habanero/CFString.h>
#include <Habanero/CFPtr.h>
#include <Utility/OrthodoxMonospace.h>
#include "TranslateMaps.h"

namespace nc::term {

static std::u32string ConvertUTF8ToUTF32( std::string_view _utf8 );
static std::u32string ComposeUnicodePoints( std::u32string _utf32 );
static void ApplyTranslateMap( std::u32string &_utf32, const unsigned short *_map );

InterpreterImpl::InterpreterImpl(Screen &_screen):
    m_Screen(_screen)
{
    m_Extent.height = m_Screen.Height();
    m_Extent.width = m_Screen.Width();
    m_Extent.top = 0;
    m_Extent.bottom = m_Screen.Height();
    ResetToDefaultTabStops(m_TabStops);
    UpdateCharacterAttributes();
}

InterpreterImpl::~InterpreterImpl()
{
}

void InterpreterImpl::Interpret( Input _to_interpret )
{
    for( const auto &command: _to_interpret )
        InterpretSingleCommand(command);
}

void InterpreterImpl::Interpret( const input::Command& _command )
{
    InterpretSingleCommand(_command);
}

void InterpreterImpl::InterpretSingleCommand( const input::Command& _command )
{
    using namespace input;
    const auto type = _command.type;
    switch (type) {
        case Type::text:
            ProcessText( *std::get_if<UTF8Text>(&_command.payload) );
            break;
        case Type::line_feed:
            ProcessLF();
            break;
        case Type::carriage_return:
            ProcessCR();
            break;
        case Type::back_space:
            ProcessBS();
            break;
        case Type::reverse_index:
            ProcessRI();
            break;
        case Type::move_cursor:
            ProcessMC( *std::get_if<CursorMovement>(&_command.payload) );
            break;
        case Type::horizontal_tab:
            ProcessHT( *std::get_if<signed>(&_command.payload) );
            break;
        case Type::report:
            ProcessReport( *std::get_if<DeviceReport>(&_command.payload) );
            break;
        case Type::bell:
            ProcessBell();
            break;
        case Type::screen_alignment_test:
            ProcessScreenAlignment();
            break;
        case Type::erase_in_display:
            ProcessEraseInDisplay( *std::get_if<DisplayErasure>(&_command.payload) );
            break;
        case Type::erase_in_line:
            ProcessEraseInLine( *std::get_if<LineErasure>(&_command.payload) );
            break;
        case Type::set_scrolling_region:
            ProcessSetScrollingRegion( *std::get_if<ScrollingRegion>(&_command.payload) );
            break;
        case Type::change_mode:
            ProcessChangeMode( *std::get_if<ModeChange>(&_command.payload) );
            break;
        case Type::set_tab:
            ProcessHTS();
            break;
        case Type::clear_tab:
            ProcessClearTab( *std::get_if<TabClear>(&_command.payload) );
            break;
        case Type::set_character_attributes:
            ProcessSetCharacterAttributes( *std::get_if<CharacterAttributes>(&_command.payload) );
            break;
        case Type::designate_character_set:
            ProcessDesignateCharacterSet(*std::get_if<CharacterSetDesignation>(&_command.payload) );
            break;
        case Type::select_character_set:
            ProcessSelectCharacterSet( *std::get_if<unsigned>(&_command.payload) );
            break;
        case Type::save_state:
            ProcessSaveState();
            break;
        case Type::restore_state:
            ProcessRestoreState();
            break;
        default:
            break;
    }
}

void InterpreterImpl::SetOuput( Output _output )
{
    m_Output = std::move(_output);
}

void InterpreterImpl::SetBell( Bell _bell )
{
    m_Bell = std::move(_bell);
}

void InterpreterImpl::ProcessText( const input::UTF8Text &_text )
{
    auto uncomposed_utf32 = ConvertUTF8ToUTF32( _text.characters );
    if( m_TranslateMap != nullptr ) {
        ApplyTranslateMap(uncomposed_utf32, m_TranslateMap);
    }
    
    const auto utf32 = ComposeUnicodePoints( std::move(uncomposed_utf32) );
    
    for( const auto c: utf32 ) {
    
        if( m_AutoWrapMode == true &&
           m_Screen.CursorX() >= m_Screen.Width() - 1 &&
           m_Screen.LineOverflown() &&
           !oms::IsUnicodeCombiningCharacter(c) ) {
            m_Screen.PutWrap();
            ProcessCR();
            ProcessLF();
        }
//
//        if(m_InsertMode)
//            m_Scr.DoShiftRowRight(oms::WCWidthMin1(c));    
//    
        m_Screen.PutCh(c);
    }
    // TODO: MUCH STUFF
}

void InterpreterImpl::ProcessLF()
{
    if( m_Screen.CursorY() + 1 == m_Extent.bottom )
        m_Screen.DoScrollUp( m_Extent.top, m_Extent.bottom, 1 );
    else
        m_Screen.DoCursorDown();
}

void InterpreterImpl::ProcessCR()
{
    m_Screen.GoTo( 0, m_Screen.CursorY() );
}

void InterpreterImpl::ProcessBS()
{
    m_Screen.DoCursorLeft();
}

void InterpreterImpl::ProcessRI()
{
    if( m_Screen.CursorY() == m_Extent.top )
        m_Screen.ScrollDown( m_Extent.top, m_Extent.bottom, 1);
    else {
        const int x = m_Screen.CursorX();
        const int y = m_Screen.CursorY();
        const auto target_y = m_OriginLineMode ?
            std::clamp(y - 1,
                       m_Extent.top,
                       m_Extent.bottom - 1) :
            std::clamp(y - 1,
                       0,
                       m_Extent.height - 1);
        m_Screen.GoTo( x, target_y );
    }
}

void InterpreterImpl::ProcessMC( const input::CursorMovement _cursor_movement )
{
    if( _cursor_movement.positioning == input::CursorMovement::Absolute ) {
        const int line_basis = m_OriginLineMode ? m_Extent.top : 0;
        if( _cursor_movement.x != std::nullopt && _cursor_movement.y != std::nullopt ) {
            m_Screen.GoTo( *_cursor_movement.x, *_cursor_movement.y + line_basis );
        }
        else if( _cursor_movement.x != std::nullopt && _cursor_movement.y == std::nullopt ) {
            m_Screen.GoTo( *_cursor_movement.x, m_Screen.CursorY() );
        }
        else if( _cursor_movement.x == std::nullopt && _cursor_movement.y != std::nullopt ) {
            m_Screen.GoTo( m_Screen.CursorX(), *_cursor_movement.y + line_basis );
        }
    }
    if( _cursor_movement.positioning == input::CursorMovement::Relative ) {
        const int x = m_Screen.CursorX();
        const int y = m_Screen.CursorY();
        if( _cursor_movement.x != std::nullopt && _cursor_movement.y != std::nullopt ) {
            const auto target_y = m_OriginLineMode ?
                std::clamp(y + *_cursor_movement.y,
                           m_Extent.top,
                           m_Extent.bottom - 1) :
                (y + *_cursor_movement.y);
            m_Screen.GoTo( x + *_cursor_movement.x, target_y );
        }
        else if( _cursor_movement.x != std::nullopt && _cursor_movement.y == std::nullopt ) {
            m_Screen.GoTo( x + *_cursor_movement.x, y );
        }
        else if( _cursor_movement.x == std::nullopt && _cursor_movement.y != std::nullopt ) {
            m_Screen.GoTo( x, y + *_cursor_movement.y );
        }
    }    
}

void InterpreterImpl::ProcessHT( signed _amount )
{
    if( _amount == 0 )
        return;
    else if( _amount > 0 ) {
        const int screen_width = m_Screen.Width();
        const int tab_stops_width = static_cast<int>(m_TabStops.size());
        const int width = std::min(screen_width, tab_stops_width);
        int x = m_Screen.CursorX();
        while( x < width - 1 && _amount > 0) {
            ++x;
            if( m_TabStops[x] )
                --_amount;
        }
        m_Screen.GoTo( x, m_Screen.CursorY() );                        
    }
    else if( _amount < 0 ) {
        int x = m_Screen.CursorX();
        while( x > 0 && _amount < 0) {
            --x;
            if( m_TabStops[x] )
                ++_amount;        
        }
        m_Screen.GoTo( x, m_Screen.CursorY() );
    }
}

void InterpreterImpl::ProcessHTS()
{
    const size_t x = static_cast<size_t>(m_Screen.CursorX());
    if( x < m_TabStops.size() ) {
        m_TabStops[x] = true;
    }
}

void InterpreterImpl::ProcessReport( const input::DeviceReport _device_report )
{
    using input::DeviceReport;
    if( _device_report.mode == DeviceReport::TerminalId ) {
        // reporting our id as VT102
        const auto myid = "\033[?6c";
        Response(myid);
    }
    if( _device_report.mode == DeviceReport::DeviceStatus ) {
        const auto ok = "\033[0n";
        Response(ok);
    }
    if( _device_report.mode == DeviceReport::CursorPosition ) {
        char buf[64];
        const int x = m_Screen.CursorX();
        const int y = m_OriginLineMode ? m_Screen.CursorY() - m_Extent.top : m_Screen.CursorY();
        snprintf(buf, sizeof(buf), "\033[%d;%dR", y + 1, x + 1 );
        Response(buf);
    }
}

void InterpreterImpl::ProcessBell()
{
    assert( m_Bell );
    m_Bell();
}

void InterpreterImpl::ProcessScreenAlignment()
{
    // + fill screen with 'E'
    // - set the margins to the extremes of the page
    // + move the cursor to the home position.
    auto erase_char = m_Screen.Buffer().EraseChar();
    erase_char.l = 'E';
    m_Screen.FillScreenWithSpace(erase_char);
    m_Screen.GoTo(0, 0);
}

void InterpreterImpl::ProcessEraseInDisplay( const input::DisplayErasure _display_erasure )
{
    switch (_display_erasure.what_to_erase) {
        case input::DisplayErasure::Area::FromCursorToDisplayEnd:
            m_Screen.DoEraseScreen(0);
            break;
        case input::DisplayErasure::Area::FromDisplayStartToCursor:
            m_Screen.DoEraseScreen(1);
            break;
        case input::DisplayErasure::Area::WholeDisplay:
            m_Screen.DoEraseScreen(2);
            break;
        case input::DisplayErasure::Area::WholeDisplayWithScrollback:
            throw std::logic_error("WholeDisplayWithScrollback unimplemented");
            break;
    }
}

void InterpreterImpl::ProcessEraseInLine( const input::LineErasure _line_erasure )
{
    switch( _line_erasure.what_to_erase ) {
        case input::LineErasure::Area::FromCursorToLineEnd:
            m_Screen.EraseInLine(0);
            break;
        case input::LineErasure::Area::FromLineStartToCursor:
            m_Screen.EraseInLine(1);
            break;
        case input::LineErasure::Area::WholeLine:
            m_Screen.EraseInLine(2);
            break;
    }
}

void InterpreterImpl::ProcessSetScrollingRegion( const input::ScrollingRegion _scrolling_region )
{
    if( _scrolling_region.range ) {
        if( _scrolling_region.range->top + 1 < _scrolling_region.range->bottom &&
           _scrolling_region.range->top >= 0 &&
           _scrolling_region.range->top <= m_Screen.Height()
           ) {
            // check indices!
            m_Extent.top = _scrolling_region.range->top;
            m_Extent.bottom = _scrolling_region.range->bottom;
        }
    }
    else {
        m_Extent.top = 0;
        m_Extent.bottom = m_Screen.Height();
    }
    if( m_OriginLineMode ) {
        m_Screen.GoTo( 0, m_Extent.top );
    }
}

void InterpreterImpl::ProcessChangeMode( const input::ModeChange _mode_change )
{
    switch ( _mode_change.mode ) {
        case input::ModeChange::Kind::Origin:
            m_OriginLineMode = _mode_change.status;
            break;
        case input::ModeChange::Kind::AutoWrap:
            m_AutoWrapMode = _mode_change.status;
            break;
        case input::ModeChange::Kind::Column132:
            ProcessChangeColumnMode132(_mode_change.status);
            break;
        case input::ModeChange::Kind::ReverseVideo:
            m_Screen.SetVideoReverse(_mode_change.status);
            break;
        default:
            break;
    }
}

void InterpreterImpl::ProcessChangeColumnMode132( bool _on )
{
    if( m_AllowScreenResize == false )
        return;
    
    const auto height = m_Screen.Height();
    if( _on ) {
        // toggle 132-column mode
        m_Screen.ResizeScreen(132, height);
    }
    else {
        // toggle 80-column mode
        m_Screen.ResizeScreen(80, height);
    }
}

void  InterpreterImpl::ProcessClearTab( input::TabClear _tab_clear )
{
    if( _tab_clear.mode == input::TabClear::CurrentColumn ) {
        const size_t x = static_cast<size_t>(m_Screen.CursorX());
        if( x < m_TabStops.size() ) {
            m_TabStops[x] = false;
        }
    }
    else {
        m_TabStops.reset();
    }
}

void InterpreterImpl::ProcessSetCharacterAttributes( input::CharacterAttributes _attributes )
{
    auto set_fg = [this]( std::uint8_t _color ) {
        m_Rendition.fg_color = _color;
        m_Screen.SetFgColor(_color);
    };
    auto set_bg = [this]( std::uint8_t _color ) {
        m_Rendition.bg_color = _color;
        m_Screen.SetBgColor(_color);
    };
    auto set_faint = [this]( bool _faint ) {
        m_Rendition.faint = _faint;
        m_Screen.SetIntensity(!_faint);
    };
    auto set_inverse = [this]( bool _inverse ) {
        m_Rendition.inverse = _inverse;
        m_Screen.SetReverse(_inverse);
    };
    auto set_bold = [this]( bool _bold ) {
        m_Rendition.bold = _bold;
        m_Screen.SetBold(_bold);
    };
    auto set_italic = [this]( bool _italic ) {
        m_Rendition.italic = _italic;
        m_Screen.SetItalic(_italic);
    };
    auto set_invisible = [this]( bool _invisible ) {
        m_Rendition.invisible = _invisible;
        m_Screen.SetInvisible(_invisible);
    };
    auto set_blink = [this]( bool _blink ) {
        m_Rendition.blink = _blink;
        m_Screen.SetBlink(_blink);
    };
    auto set_underline = [this]( bool _underline ) {
        m_Rendition.underline = _underline;
        m_Screen.SetUnderline(_underline);
    };
    
    using Kind = input::CharacterAttributes::Kind;
    switch (_attributes.mode) {
        case Kind::Normal:
            set_faint(false);
            set_inverse(false);
            set_bold(false);
            set_italic(false);
            set_invisible(false);
            set_blink(false);
            set_underline(false);
            set_fg(ScreenColors::Default);
            set_bg(ScreenColors::Default);
            break;
        case Kind::Faint: set_faint(true); break;
        case Kind::NotBoldNotFaint: set_faint(false); set_bold(false); break;
        case Kind::Inverse: set_inverse(true); break;
        case Kind::NotInverse: set_inverse(false); break;
        case Kind::Bold: set_bold(true); break;
        case Kind::Italicized: set_italic(true); break;
        case Kind::NotItalicized: set_italic(false); break;
        case Kind::Invisible: set_invisible(true); break;
        case Kind::NotInvisible: set_invisible(false); break;
        case Kind::Blink: set_blink(true); break;
        case Kind::NotBlink: set_blink(false); break;
        case Kind::Underlined: set_underline(true); break;
        case Kind::DoublyUnderlined: set_underline(true); break;
        case Kind::NotUnderlined: set_underline(false); break;
        case Kind::ForegroundBlack: set_fg(ScreenColors::Black); break;
        case Kind::ForegroundRed: set_fg(ScreenColors::Red); break;
        case Kind::ForegroundGreen: set_fg(ScreenColors::Green); break;
        case Kind::ForegroundYellow: set_fg(ScreenColors::Yellow); break;
        case Kind::ForegroundBlue: set_fg(ScreenColors::Blue); break;
        case Kind::ForegroundMagenta: set_fg(ScreenColors::Magenta); break;
        case Kind::ForegroundCyan: set_fg(ScreenColors::Cyan); break;
        case Kind::ForegroundWhite: set_fg(ScreenColors::White); break;
        case Kind::ForegroundDefault: set_bg(ScreenColors::Default); break;
        case Kind::BackgroundBlack: set_bg(ScreenColors::Black); break;
        case Kind::BackgroundRed: set_bg(ScreenColors::Red); break;
        case Kind::BackgroundGreen: set_bg(ScreenColors::Green); break;
        case Kind::BackgroundYellow: set_bg(ScreenColors::Yellow); break;
        case Kind::BackgroundBlue: set_bg(ScreenColors::Blue); break;
        case Kind::BackgroundMagenta: set_bg(ScreenColors::Magenta); break;
        case Kind::BackgroundCyan: set_bg(ScreenColors::Cyan); break;
        case Kind::BackgroundWhite: set_bg(ScreenColors::White); break;
        case Kind::BackgroundDefault: set_bg(ScreenColors::Default); break;
        default: break;
    }
}

void InterpreterImpl::UpdateCharacterAttributes()
{
    m_Screen.SetFgColor(m_Rendition.fg_color);
    m_Screen.SetBgColor(m_Rendition.bg_color);
    m_Screen.SetIntensity(!m_Rendition.faint);
    m_Screen.SetReverse(m_Rendition.inverse);
    m_Screen.SetBold(m_Rendition.bold);
    m_Screen.SetItalic(m_Rendition.italic);
    m_Screen.SetInvisible(m_Rendition.invisible);
    m_Screen.SetBlink(m_Rendition.blink);
    m_Screen.SetUnderline(m_Rendition.underline);
}

void InterpreterImpl::Response(std::string_view _text)
{
    assert( m_Output );
    Bytes bytes{reinterpret_cast<const std::byte*>(_text.data()), _text.length()}; 
    m_Output(bytes);
}

static std::u32string ConvertUTF8ToUTF32( std::string_view _utf8 )
{
    // temp and slow implementation
    auto str = base::CFPtr<CFStringRef>::adopt( CFStringCreateWithUTF8StringNoCopy( _utf8) ); 
    if( !str )
        return {};
    
    const auto utf16_len = CFStringGetLength(str.get());
    const auto utf32_len = CFStringGetBytes(str.get(),
                                            CFRangeMake(0, utf16_len),
                                            kCFStringEncodingUTF32LE,
                                            0,
                                            false,
                                            nullptr,
                                            0,
                                            nullptr);
    if( utf32_len == 0 )
        return {};
        
    std::u32string result;
    result.resize(utf32_len);
            
    const auto utf32_fact = CFStringGetBytes(str.get(),
                                            CFRangeMake(0, utf16_len),
                                            kCFStringEncodingUTF32LE,
                                            0,
                                            false,
                                            reinterpret_cast<UInt8*>(result.data()),
                                            result.size() * sizeof(char32_t),
                                            nullptr);
                                            
    assert( utf32_len == utf32_fact );

    return result; 
}

static std::u32string ComposeUnicodePoints( std::u32string _utf32 )
{
    // temp and slow implementation
    const bool can_be_composed = std::any_of(_utf32.begin(), _utf32.end(), [](const char32_t _c){
        return oms::CanCharBeTheoreticallyComposed(_c);
    });
    if( can_be_composed == false )
        return _utf32;

    const auto orig_str = base::CFPtr<CFStringRef>::adopt(CFStringCreateWithBytesNoCopy(nullptr,
                                                                                        (UInt8*)_utf32.data(),
                                                                                        _utf32.length() * sizeof(char32_t),
                                                                                        kCFStringEncodingUTF32LE,
                                                                                        false,
                                                                                        kCFAllocatorNull) );
                                                                                            
    const auto mut_str = base::CFPtr<CFMutableStringRef>::adopt(CFStringCreateMutableCopy(nullptr,
                                                                                          0,
                                                                                          orig_str.get()) );
                                                                                              
    CFStringNormalize(mut_str.get(), kCFStringNormalizationFormC);
    const auto utf16_len = CFStringGetLength(mut_str.get());

    const auto utf32_len = CFStringGetBytes(mut_str.get(),
                                            CFRangeMake(0, utf16_len),
                                            kCFStringEncodingUTF32LE,
                                            0,
                                            false,
                                            nullptr,
                                            0,
                                            nullptr);
    if( utf32_len == 0 )
        return {};
        
    _utf32.resize(utf32_len);
            
    const auto utf32_fact = CFStringGetBytes(mut_str.get(),
                                            CFRangeMake(0, utf16_len),
                                            kCFStringEncodingUTF32LE,
                                            0,
                                            false,
                                            reinterpret_cast<UInt8*>(_utf32.data()),
                                            _utf32.size() * sizeof(char32_t),
                                            nullptr);
                                            
    assert( utf32_len == utf32_fact );        
    
    return _utf32;
}

static void ApplyTranslateMap( std::u32string &_utf32, const unsigned short *_map )
{
    for( auto &c: _utf32 ) {
        if( c <= 0x7f ) {
            c = _map[c];
        }
    }
}

void InterpreterImpl::ResetToDefaultTabStops(TabStops &_tab_stops)
{
    _tab_stops.reset();
    for( size_t n = 0; n < _tab_stops.size(); n += 8 )
        _tab_stops.set(n, true);
}

bool InterpreterImpl::ScreenResizeAllowed()
{
    return m_AllowScreenResize;
}

void InterpreterImpl::SetScreenResizeAllowed( bool _allow )
{
    m_AllowScreenResize = _allow;
}

void InterpreterImpl::ProcessDesignateCharacterSet(input::CharacterSetDesignation _designation) {
    unsigned codeset = 0;
    switch( _designation.set ) {
        case input::CharacterSetDesignation::DECSpecialGraphics:
        case input::CharacterSetDesignation::AlternateCharacterROMSpecialGraphics:
            codeset = TranslateMaps::Graph;
            break;
        case input::CharacterSetDesignation::UK:
            codeset = TranslateMaps::UK;
            break;
        case input::CharacterSetDesignation::USASCII:
        case input::CharacterSetDesignation::AlternateCharacterROMStandardCharacters:
            codeset = TranslateMaps::USASCII;
            break;
        default: return;
    }

    if( _designation.target < m_CS.Gx.size() ) {
        m_CS.Gx[_designation.target] = codeset;
    }
    else {
        return;
    }
        
    if( codeset == TranslateMaps::USASCII ) {
        m_TranslateMap = nullptr;
    }
    else {
        m_TranslateMap = g_TranslateMaps[codeset];
    }
}

void InterpreterImpl::ProcessSelectCharacterSet( unsigned _target )
{
    if( _target < m_CS.Gx.size() ) {
        const auto codeset = m_CS.Gx[_target];
        if( codeset == TranslateMaps::USASCII )
            m_TranslateMap = nullptr;
        else
            m_TranslateMap = g_TranslateMaps[codeset];
    }
}

void InterpreterImpl::ProcessSaveState()
{
    SavedState state;
    state.x = m_Screen.CursorX();
    state.y = m_Screen.CursorY();
    state.rendition = m_Rendition;
    state.character_sets = m_CS;
    state.translate_map = m_TranslateMap;
    m_SavedState = state;
}

void InterpreterImpl::ProcessRestoreState()
{
    if( m_SavedState == std::nullopt )
        return;
    m_Screen.GoTo(m_SavedState->x, m_SavedState->y);    
    m_CS = m_SavedState->character_sets;
    m_TranslateMap = m_SavedState->translate_map;
    m_Rendition = m_SavedState->rendition;
    UpdateCharacterAttributes();
}

}
