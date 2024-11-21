// Copyright (C) 2020-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "InterpreterImpl.h"
#include <Base/CFString.h>
#include <Base/CFPtr.h>
#include <Utility/CharInfo.h>
#include <magic_enum.hpp>
#include "OrthodoxMonospace.h"
#include "TranslateMaps.h"
#include "Log.h"
#include <fmt/format.h>

namespace nc::term {

static std::u16string ConvertUTF8ToUTF16(std::string_view _utf8);
static void ApplyTranslateMap(std::u16string &_utf16, const unsigned short *_map);

InterpreterImpl::InterpreterImpl(Screen &_screen, ExtendedCharRegistry &_reg) : m_Screen(_screen), m_Registry(_reg)
{
    m_Extent.height = m_Screen.Height();
    m_Extent.width = m_Screen.Width();
    m_Extent.top = 0;
    m_Extent.bottom = m_Screen.Height();
    ResetToDefaultTabStops(m_TabStops);
    UpdateCharacterAttributes();
}

InterpreterImpl::~InterpreterImpl() = default;

void InterpreterImpl::Interpret(Input _to_interpret)
{
    for( const auto &command : _to_interpret )
        InterpretSingleCommand(command);
}

void InterpreterImpl::Interpret(const input::Command &_command)
{
    InterpretSingleCommand(_command);
}

void InterpreterImpl::InterpretSingleCommand(const input::Command &_command)
{
    using namespace input;
    const auto type = _command.type;
    switch( type ) {
        case Type::text:
            ProcessText(*std::get_if<UTF8Text>(&_command.payload));
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
            ProcessMC(*std::get_if<CursorMovement>(&_command.payload));
            break;
        case Type::horizontal_tab:
            ProcessHT(*std::get_if<signed>(&_command.payload));
            break;
        case Type::report:
            ProcessReport(*std::get_if<DeviceReport>(&_command.payload));
            break;
        case Type::bell:
            ProcessBell();
            break;
        case Type::screen_alignment_test:
            ProcessScreenAlignment();
            break;
        case Type::erase_in_display:
            ProcessEraseInDisplay(*std::get_if<DisplayErasure>(&_command.payload));
            break;
        case Type::erase_in_line:
            ProcessEraseInLine(*std::get_if<LineErasure>(&_command.payload));
            break;
        case Type::erase_characters:
            ProcessEraseCharacters(*std::get_if<unsigned>(&_command.payload));
            break;
        case Type::set_scrolling_region:
            ProcessSetScrollingRegion(*std::get_if<ScrollingRegion>(&_command.payload));
            break;
        case Type::change_mode:
            ProcessChangeMode(*std::get_if<ModeChange>(&_command.payload));
            break;
        case Type::set_tab:
            ProcessHTS();
            break;
        case Type::clear_tab:
            ProcessClearTab(*std::get_if<TabClear>(&_command.payload));
            break;
        case Type::set_character_attributes:
            ProcessSetCharacterAttributes(*std::get_if<CharacterAttributes>(&_command.payload));
            break;
        case Type::designate_character_set:
            ProcessDesignateCharacterSet(*std::get_if<CharacterSetDesignation>(&_command.payload));
            break;
        case Type::select_character_set:
            ProcessSelectCharacterSet(*std::get_if<unsigned>(&_command.payload));
            break;
        case Type::save_state:
            ProcessSaveState();
            break;
        case Type::restore_state:
            ProcessRestoreState();
            break;
        case Type::insert_lines:
            ProcessInsertLines(*std::get_if<unsigned>(&_command.payload));
            break;
        case Type::delete_lines:
            ProcessDeleteLines(*std::get_if<unsigned>(&_command.payload));
            break;
        case Type::delete_characters:
            ProcessDeleteCharacters(*std::get_if<unsigned>(&_command.payload));
            break;
        case Type::insert_characters:
            ProcessInsertCharacters(*std::get_if<unsigned>(&_command.payload));
            break;
        case Type::change_title:
            ProcessChangeTitle(*std::get_if<input::Title>(&_command.payload));
            break;
        case Type::manipulate_title:
            ProcessTitleManipulation(*std::get_if<input::TitleManipulation>(&_command.payload));
            break;
        case Type::set_cursor_style:
            ProcessCursorStyle(*std::get_if<input::CursorStyle>(&_command.payload));
            break;
        default:
            Log::Warn("Interpreter::InterpretSingleCommand: missed {}", magic_enum::enum_name(type));
            break;
    }
}

void InterpreterImpl::SetOuput(Output _output)
{
    m_Output = std::move(_output);
}

void InterpreterImpl::SetBell(Bell _bell)
{
    m_Bell = std::move(_bell);
}

void InterpreterImpl::ProcessText(const input::UTF8Text &_text)
{
    // TODO: convert iteratively, avoid CF for conversion and use raw local stack buffers
    auto whole_input = ConvertUTF8ToUTF16(_text.characters);
    if( m_TranslateMap != nullptr ) {
        ApplyTranslateMap(whole_input, m_TranslateMap);
    }

    // 'input' will gradually decrease after being eaten from the front
    std::u16string_view input = whole_input;
    if( input.empty() )
        return; // ignore empty inputs

    // first try to append a whatever character currently stored at the current position
    if( const char32_t curr = m_Screen.GetCh(); curr != 0 && curr != Screen::MultiCellGlyph ) {
        const auto ar = m_Registry.Append(input, curr);
        if( ar.eaten != 0 ) {
            // managed to append something to the current character
            assert(curr != ar.newchar);
            assert(ar.eaten <= input.size());
            m_Screen.PutCh(ar.newchar);
            input = input.substr(ar.eaten);
        }
    }

    const int sx = m_Screen.Width();

    auto curr_line_ends_with_mcg = [&]() -> bool {
        auto line = m_Screen.Buffer().LineFromNo(m_Screen.CursorY());
        return line.back().l == Screen::MultiCellGlyph;
    };

    while( !input.empty() ) {
        const auto ar = m_Registry.Append(input);
        assert(ar.eaten <= input.size());
        input = input.substr(ar.eaten);
        if( ar.newchar == 0 ) {
            continue;
        }

        if( m_AutoWrapMode && m_Screen.LineOverflown() &&
            (m_Screen.CursorX() >= sx - 1 || (m_Screen.CursorX() == sx - 2 && curr_line_ends_with_mcg())) ) {
            m_Screen.PutWrap();
            ProcessCR();
            ProcessLF();
        }

        const bool is_dw = m_Registry.IsDoubleWidth(ar.newchar);
        const int char_width = is_dw ? 2 : 1;

        if( m_InsertMode )
            m_Screen.DoShiftRowRight(char_width);

        m_Screen.PutCh(ar.newchar);

        if( m_Screen.CursorX() + char_width < sx ) {
            m_Screen.GoTo(m_Screen.CursorX() + char_width, m_Screen.CursorY());
        }
    }
}

void InterpreterImpl::ProcessLF()
{
    if( m_Screen.CursorY() + 1 == m_Extent.bottom )
        m_Screen.DoScrollUp(m_Extent.top, m_Extent.bottom, 1);
    else
        m_Screen.DoCursorDown();
}

void InterpreterImpl::ProcessCR()
{
    m_Screen.GoTo(0, m_Screen.CursorY());
}

void InterpreterImpl::ProcessBS()
{
    m_Screen.DoCursorLeft();
}

void InterpreterImpl::ProcessRI()
{
    if( m_Screen.CursorY() == m_Extent.top )
        m_Screen.ScrollDown(m_Extent.top, m_Extent.bottom, 1);
    else {
        const int x = m_Screen.CursorX();
        const int y = m_Screen.CursorY();
        const auto target_y = m_OriginLineMode ? std::clamp(y - 1, m_Extent.top, m_Extent.bottom - 1)
                                               : std::clamp(y - 1, 0, m_Extent.height - 1);
        m_Screen.GoTo(x, target_y);
    }
}

void InterpreterImpl::ProcessMC(const input::CursorMovement _cursor_movement)
{
    if( _cursor_movement.positioning == input::CursorMovement::Absolute ) {
        const int line_basis = m_OriginLineMode ? m_Extent.top : 0;
        if( _cursor_movement.x != std::nullopt && _cursor_movement.y != std::nullopt ) {
            m_Screen.GoTo(*_cursor_movement.x, *_cursor_movement.y + line_basis);
        }
        else if( _cursor_movement.x != std::nullopt && _cursor_movement.y == std::nullopt ) {
            m_Screen.GoTo(*_cursor_movement.x, m_Screen.CursorY());
        }
        else if( _cursor_movement.x == std::nullopt && _cursor_movement.y != std::nullopt ) {
            m_Screen.GoTo(m_Screen.CursorX(), *_cursor_movement.y + line_basis);
        }
    }
    if( _cursor_movement.positioning == input::CursorMovement::Relative ) {
        const int x = m_Screen.CursorX();
        const int y = m_Screen.CursorY();
        if( _cursor_movement.x != std::nullopt && _cursor_movement.y != std::nullopt ) {
            const auto target_y = m_OriginLineMode
                                      ? std::clamp(y + *_cursor_movement.y, m_Extent.top, m_Extent.bottom - 1)
                                      : (y + *_cursor_movement.y);
            m_Screen.GoTo(x + *_cursor_movement.x, target_y);
        }
        else if( _cursor_movement.x != std::nullopt && _cursor_movement.y == std::nullopt ) {
            m_Screen.GoTo(x + *_cursor_movement.x, y);
        }
        else if( _cursor_movement.x == std::nullopt && _cursor_movement.y != std::nullopt ) {
            m_Screen.GoTo(x, y + *_cursor_movement.y);
        }
    }
}

void InterpreterImpl::ProcessHT(signed _amount)
{
    if( _amount == 0 )
        return;
    else if( _amount > 0 ) {
        const int screen_width = m_Screen.Width();
        const int tab_stops_width = static_cast<int>(m_TabStops.size());
        const int width = std::min(screen_width, tab_stops_width);
        int x = m_Screen.CursorX();
        while( x < width - 1 && _amount > 0 ) {
            ++x;
            if( m_TabStops[x] )
                --_amount;
        }
        m_Screen.GoTo(x, m_Screen.CursorY());
    }
    else if( _amount < 0 ) {
        int x = m_Screen.CursorX();
        while( x > 0 && _amount < 0 ) {
            --x;
            if( m_TabStops[x] )
                ++_amount;
        }
        m_Screen.GoTo(x, m_Screen.CursorY());
    }
}

void InterpreterImpl::ProcessHTS()
{
    const size_t x = static_cast<size_t>(m_Screen.CursorX());
    if( x < m_TabStops.size() ) {
        m_TabStops[x] = true;
    }
}

void InterpreterImpl::ProcessReport(const input::DeviceReport _device_report)
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
        *fmt::format_to(buf, "\033[{};{}R", y + 1, x + 1) = 0;
        Response(buf);
    }
}

void InterpreterImpl::ProcessBell()
{
    assert(m_Bell);
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

void InterpreterImpl::ProcessEraseInDisplay(const input::DisplayErasure _display_erasure)
{
    switch( _display_erasure.what_to_erase ) {
        case input::DisplayErasure::Area::FromCursorToDisplayEnd:
            m_Screen.DoEraseScreen(0);
            break;
        case input::DisplayErasure::Area::FromDisplayStartToCursor:
            m_Screen.DoEraseScreen(1);
            break;
        case input::DisplayErasure::Area::WholeDisplayWithScrollback: // TODO: need a real implementation
        case input::DisplayErasure::Area::WholeDisplay:
            m_Screen.DoEraseScreen(2);
            break;
    }
}

void InterpreterImpl::ProcessEraseInLine(const input::LineErasure _line_erasure)
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

void InterpreterImpl::ProcessEraseCharacters(unsigned _amount)
{
    if( _amount == 0 )
        return;
    m_Screen.EraseAt(m_Screen.CursorX(), m_Screen.CursorY(), _amount);
}

void InterpreterImpl::ProcessSetScrollingRegion(const input::ScrollingRegion _scrolling_region)
{
    if( _scrolling_region.range ) {
        if( _scrolling_region.range->top + 1 < _scrolling_region.range->bottom && _scrolling_region.range->top >= 0 &&
            _scrolling_region.range->top <= m_Screen.Height() ) {
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
        m_Screen.GoTo(0, m_Extent.top);
    }
}

void InterpreterImpl::ProcessChangeMode(const input::ModeChange _mode_change)
{
    using Kind = input::ModeChange::Kind;
    switch( _mode_change.mode ) {
        case Kind::Origin:
            m_OriginLineMode = _mode_change.status;
            break;
        case Kind::AutoWrap:
            m_AutoWrapMode = _mode_change.status;
            break;
        case Kind::Column132:
            ProcessChangeColumnMode132(_mode_change.status);
            break;
        case Kind::ReverseVideo:
            m_Screen.SetVideoReverse(_mode_change.status);
            break;
        case Kind::Insert:
            m_InsertMode = _mode_change.status;
            break;
        case Kind::ApplicationCursorKeys:
            if( m_InputTranslator )
                m_InputTranslator->SetApplicationCursorKeys(_mode_change.status);
            break;
        case Kind::BracketedPaste:
            if( m_InputTranslator )
                m_InputTranslator->SetBracketedPaste(_mode_change.status);
            break;
        case Kind::AlternateScreenBuffer:
            m_Screen.SetAlternateScreen(_mode_change.status);
            break;
        case Kind::AlternateScreenBuffer1049:
            m_Screen.SetAlternateScreen(_mode_change.status);
            if( _mode_change.status )
                ProcessEraseInDisplay(input::DisplayErasure{input::DisplayErasure::WholeDisplay});
            break;
        case Kind::ShowCursor:
            if( _mode_change.status != m_CursorShown ) {
                m_CursorShown = _mode_change.status;
                m_OnShowCursorChanged(m_CursorShown);
            }
            break;
        // TODO: process BlinkingCursor!
        case Kind::SendMouseReportUFT8:
            if( _mode_change.status != m_MouseReportingUTF8 ) {
                m_MouseReportingUTF8 = _mode_change.status;
                UpdateMouseReporting();
            }
            break;
        case Kind::SendMouseReportSGR:
            if( _mode_change.status != m_MouseReportingSGR ) {
                m_MouseReportingSGR = _mode_change.status;
                UpdateMouseReporting();
            }
            break;
        case Kind::SendMouseXYOnPress:
            if( _mode_change.status && m_RequestedMouseEvents != RequestedMouseEvents::X10 ) {
                m_RequestedMouseEvents = RequestedMouseEvents::X10;
                RequestMouseEventsChanged();
            }
            if( !_mode_change.status && m_RequestedMouseEvents == RequestedMouseEvents::X10 ) {
                m_RequestedMouseEvents = RequestedMouseEvents::None;
                RequestMouseEventsChanged();
            }
            break;
        case Kind::SendMouseXYOnPressAndRelease:
            if( _mode_change.status && m_RequestedMouseEvents != RequestedMouseEvents::Normal ) {
                m_RequestedMouseEvents = RequestedMouseEvents::Normal;
                RequestMouseEventsChanged();
            }
            if( !_mode_change.status && m_RequestedMouseEvents == RequestedMouseEvents::Normal ) {
                m_RequestedMouseEvents = RequestedMouseEvents::None;
                RequestMouseEventsChanged();
            }
            break;
        case Kind::SendMouseXYOnPressDragAndRelease:
            if( _mode_change.status && m_RequestedMouseEvents != RequestedMouseEvents::ButtonTracking ) {
                m_RequestedMouseEvents = RequestedMouseEvents::ButtonTracking;
                RequestMouseEventsChanged();
            }
            if( !_mode_change.status && m_RequestedMouseEvents == RequestedMouseEvents::ButtonTracking ) {
                m_RequestedMouseEvents = RequestedMouseEvents::None;
                RequestMouseEventsChanged();
            }
            break;
        case Kind::SendMouseXYAnyEvent:
            if( _mode_change.status && m_RequestedMouseEvents != RequestedMouseEvents::Any ) {
                m_RequestedMouseEvents = RequestedMouseEvents::Any;
                RequestMouseEventsChanged();
            }
            if( !_mode_change.status && m_RequestedMouseEvents == RequestedMouseEvents::Any ) {
                m_RequestedMouseEvents = RequestedMouseEvents::None;
                RequestMouseEventsChanged();
            }
            break;
        default:
            break;
    }
}

void InterpreterImpl::ProcessChangeColumnMode132(bool _on)
{
    if( !m_AllowScreenResize )
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

void InterpreterImpl::ProcessClearTab(input::TabClear _tab_clear)
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

void InterpreterImpl::ProcessSetCharacterAttributes(input::CharacterAttributes _attributes)
{
    auto set_fg = [this](std::optional<Color> _color) {
        m_Rendition.fg_color = _color;
        m_Screen.SetFgColor(_color);
    };
    auto set_bg = [this](std::optional<Color> _color) {
        m_Rendition.bg_color = _color;
        m_Screen.SetBgColor(_color);
    };
    auto set_faint = [this](bool _faint) {
        m_Rendition.faint = _faint;
        m_Screen.SetFaint(_faint);
    };
    auto set_inverse = [this](bool _inverse) {
        m_Rendition.inverse = _inverse;
        m_Screen.SetReverse(_inverse);
    };
    auto set_bold = [this](bool _bold) {
        m_Rendition.bold = _bold;
        m_Screen.SetBold(_bold);
    };
    auto set_italic = [this](bool _italic) {
        m_Rendition.italic = _italic;
        m_Screen.SetItalic(_italic);
    };
    auto set_invisible = [this](bool _invisible) {
        m_Rendition.invisible = _invisible;
        m_Screen.SetInvisible(_invisible);
    };
    auto set_blink = [this](bool _blink) {
        m_Rendition.blink = _blink;
        m_Screen.SetBlink(_blink);
    };
    auto set_underline = [this](bool _underline) {
        m_Rendition.underline = _underline;
        m_Screen.SetUnderline(_underline);
    };
    auto set_crossed = [this](bool _crossed) {
        m_Rendition.crossed = _crossed;
        m_Screen.SetCrossed(_crossed);
    };

    using Kind = input::CharacterAttributes::Kind;
    switch( _attributes.mode ) {
        case Kind::Normal:
            set_faint(false);
            set_inverse(false);
            set_bold(false);
            set_italic(false);
            set_invisible(false);
            set_blink(false);
            set_underline(false);
            set_crossed(false);
            set_fg(std::nullopt);
            set_bg(std::nullopt);
            break;
        case Kind::Faint:
            set_faint(true);
            break;
        case Kind::NotBoldNotFaint:
            set_faint(false);
            set_bold(false);
            break;
        case Kind::Inverse:
            set_inverse(true);
            break;
        case Kind::NotInverse:
            set_inverse(false);
            break;
        case Kind::Bold:
            set_bold(true);
            break;
        case Kind::Italicized:
            set_italic(true);
            break;
        case Kind::NotItalicized:
            set_italic(false);
            break;
        case Kind::Invisible:
            set_invisible(true);
            break;
        case Kind::NotInvisible:
            set_invisible(false);
            break;
        case Kind::Blink:
            set_blink(true);
            break;
        case Kind::NotBlink:
            set_blink(false);
            break;
        case Kind::Underlined:
        case Kind::DoublyUnderlined:
            set_underline(true);
            break;
        case Kind::NotUnderlined:
            set_underline(false);
            break;
        case Kind::ForegroundColor:
            set_fg(_attributes.color);
            break;
        case Kind::ForegroundDefault:
            set_fg(std::nullopt);
            break;
        case input::CharacterAttributes::BackgroundColor:
            set_bg(_attributes.color);
            break;
        case Kind::BackgroundDefault:
            set_bg(std::nullopt);
            break;
        case Kind::Crossed:
            set_crossed(true);
            break;
        case Kind::NotCrossed:
            set_crossed(false);
            break;
            // no default to get a warning=error just in case
    }
}

void InterpreterImpl::UpdateCharacterAttributes()
{
    m_Screen.SetFgColor(m_Rendition.fg_color);
    m_Screen.SetBgColor(m_Rendition.bg_color);
    m_Screen.SetFaint(m_Rendition.faint);
    m_Screen.SetReverse(m_Rendition.inverse);
    m_Screen.SetBold(m_Rendition.bold);
    m_Screen.SetItalic(m_Rendition.italic);
    m_Screen.SetInvisible(m_Rendition.invisible);
    m_Screen.SetBlink(m_Rendition.blink);
    m_Screen.SetUnderline(m_Rendition.underline);
    m_Screen.SetCrossed(m_Rendition.crossed);
}

void InterpreterImpl::Response(std::string_view _text)
{
    assert(m_Output);
    const Bytes bytes{reinterpret_cast<const std::byte *>(_text.data()), _text.length()};
    m_Output(bytes);
}

static std::u16string ConvertUTF8ToUTF16(std::string_view _utf8)
{
    // temp and slow implementation
    auto str = base::CFPtr<CFStringRef>::adopt(base::CFStringCreateWithUTF8StringNoCopy(_utf8));
    if( !str )
        return {};

    const auto utf16_len = CFStringGetLength(str.get());

    std::u16string result;
    result.resize(utf16_len);

    CFStringGetCharacters(str.get(), CFRangeMake(0, utf16_len), reinterpret_cast<uint16_t *>(result.data()));

    return result;
}

static void ApplyTranslateMap(std::u16string &_utf16, const unsigned short *_map)
{
    for( auto &c : _utf16 ) {
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

void InterpreterImpl::SetScreenResizeAllowed(bool _allow)
{
    m_AllowScreenResize = _allow;
}

void InterpreterImpl::ProcessDesignateCharacterSet(input::CharacterSetDesignation _designation)
{
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
        default:
            return;
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

void InterpreterImpl::ProcessSelectCharacterSet(unsigned _target)
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

void InterpreterImpl::ProcessInsertLines(unsigned _lines)
{
    //    Only that portion of the display between the top, bottom, left, and right margins is
    //    affected. IL is ignored if the Active Position is outside the Scroll Area.
    if( m_Screen.CursorY() < m_Extent.top || m_Screen.CursorY() > m_Extent.bottom ) {
        return;
    }

    int lines = static_cast<int>(_lines);
    if( lines > m_Screen.Height() - m_Screen.CursorY() )
        lines = m_Screen.Height() - m_Screen.CursorY();
    else if( lines == 0 )
        lines = 1;

    m_Screen.ScrollDown(m_Screen.CursorY(), m_Extent.bottom, lines);
}

void InterpreterImpl::ProcessDeleteLines(unsigned _lines)
{
    //  Only that portion of the display between the top, bottom, left, and right margins is
    //  affected.
    //    DL is ignored if the active position is outside the scroll area.
    if( m_Screen.CursorY() < m_Extent.top || m_Screen.CursorY() > m_Extent.bottom ) {
        return;
    }
    int lines = static_cast<int>(_lines);
    if( lines > m_Screen.Height() - m_Screen.CursorY() )
        lines = m_Screen.Height() - m_Screen.CursorY();
    else if( lines == 0 )
        lines = 1;

    m_Screen.DoScrollUp(m_Screen.CursorY(), m_Extent.bottom, lines);
}

void InterpreterImpl::ProcessDeleteCharacters(const unsigned _characters)
{
    int chars = static_cast<int>(_characters);
    if( chars > m_Screen.Width() - m_Screen.CursorX() )
        chars = m_Screen.Width() - m_Screen.CursorX();
    else if( chars == 0 )
        chars = 1;
    m_Screen.DoShiftRowLeft(chars);
}

void InterpreterImpl::ProcessInsertCharacters(unsigned _characters)
{
    int characters = static_cast<int>(_characters);
    if( characters > m_Screen.Width() - m_Screen.CursorX() )
        characters = m_Screen.Width() - m_Screen.CursorX();
    else if( characters == 0 )
        characters = 1;
    m_Screen.DoShiftRowRight(characters);
}

void InterpreterImpl::SetInputTranslator(InputTranslator *_input_translator)
{
    m_InputTranslator = _input_translator;
}

void InterpreterImpl::NotifyScreenResized()
{
    const auto old_extent = m_Extent;
    m_Extent.width = m_Screen.Width();
    m_Extent.height = m_Screen.Height();
    if( old_extent.bottom == old_extent.height ) {
        m_Extent.bottom = m_Extent.height;
    }
    else {
        m_Extent.bottom = std::min(old_extent.bottom, m_Extent.height);
    }
    m_Extent.top = std::min(old_extent.top, m_Extent.height - 1);
}

void InterpreterImpl::SetTitle(TitleChanged _title)
{
    assert(_title);
    m_OnTitleChanged = std::move(_title);
}

void InterpreterImpl::ProcessChangeTitle(const input::Title &_title)
{
    assert(m_OnTitleChanged);
    auto &new_title = _title.title;
    if( _title.kind == input::Title::Icon ) {
        if( m_Titles.icon == new_title )
            return;
        m_Titles.icon = new_title;
        m_OnTitleChanged(new_title, TitleKind::Icon);
    }
    else if( _title.kind == input::Title::Window ) {
        if( m_Titles.window == new_title )
            return;
        m_Titles.window = new_title;
        m_OnTitleChanged(new_title, TitleKind::Window);
    }
    else if( _title.kind == input::Title::IconAndWindow ) {
        if( m_Titles.icon != new_title ) {
            m_Titles.icon = new_title;
            m_OnTitleChanged(new_title, TitleKind::Icon);
        }
        if( m_Titles.window != new_title ) {
            m_Titles.window = new_title;
            m_OnTitleChanged(_title.title, TitleKind::Window);
        }
    }
}

void InterpreterImpl::ProcessTitleManipulation(const input::TitleManipulation &_title_manipulation)
{
    if( _title_manipulation.operation == input::TitleManipulation::Save ) {
        if( _title_manipulation.target == input::TitleManipulation::Icon ) {
            m_Titles.saved_icon.emplace_back(m_Titles.icon);
        }
        else if( _title_manipulation.target == input::TitleManipulation::Window ) {
            m_Titles.saved_window.emplace_back(m_Titles.window);
        }
        else if( _title_manipulation.target == input::TitleManipulation::Both ) {
            m_Titles.saved_icon.emplace_back(m_Titles.icon);
            m_Titles.saved_window.emplace_back(m_Titles.window);
        }
    }
    else if( _title_manipulation.operation == input::TitleManipulation::Restore ) {
        if( _title_manipulation.target == input::TitleManipulation::Icon ||
            _title_manipulation.target == input::TitleManipulation::Both ) {
            if( not m_Titles.saved_icon.empty() ) {
                const input::Title cmd{.kind = input::Title::Icon, .title = m_Titles.saved_icon.back()};
                m_Titles.saved_icon.pop_back();
                ProcessChangeTitle(cmd);
            }
        }
        if( _title_manipulation.target == input::TitleManipulation::Window ||
            _title_manipulation.target == input::TitleManipulation::Both ) {
            if( not m_Titles.saved_window.empty() ) {
                const input::Title cmd{.kind = input::Title::Window, .title = m_Titles.saved_window.back()};
                m_Titles.saved_window.pop_back();
                ProcessChangeTitle(cmd);
            }
        }
    }
}

void InterpreterImpl::ProcessCursorStyle(const input::CursorStyle &_style)
{
    assert(m_OnCursorStyleChanged);
    if( _style.style )
        m_OnCursorStyleChanged(_style.style);
    else
        m_OnCursorStyleChanged(std::nullopt);
}

bool InterpreterImpl::ShowCursor()
{
    return m_CursorShown;
}

void InterpreterImpl::SetShowCursorChanged(ShownCursorChanged _on_show_cursor_changed)
{
    assert(_on_show_cursor_changed);
    m_OnShowCursorChanged = std::move(_on_show_cursor_changed);
}

void InterpreterImpl::SetCursorStyleChanged(CursorStyleChanged _on_cursor_style_changed)
{
    assert(_on_cursor_style_changed);
    m_OnCursorStyleChanged = std::move(_on_cursor_style_changed);
}

void InterpreterImpl::SetRequstedMouseEventsChanged(RequstedMouseEventsChanged _on_events_changed)
{
    assert(_on_events_changed);
    m_OnRequestedMouseEventsChanged = std::move(_on_events_changed);
}

void InterpreterImpl::UpdateMouseReporting()
{
    if( m_InputTranslator == nullptr )
        return;

    const auto events = m_RequestedMouseEvents;
    if( events == RequestedMouseEvents::X10 ) {
        m_InputTranslator->SetMouseReportingMode(InputTranslator::MouseReportingMode::X10);
    }
    if( events == RequestedMouseEvents::Normal || events == RequestedMouseEvents::ButtonTracking ||
        events == RequestedMouseEvents::Any ) {
        if( m_MouseReportingSGR )
            m_InputTranslator->SetMouseReportingMode(InputTranslator::MouseReportingMode::SGR);
        else if( m_MouseReportingUTF8 )
            m_InputTranslator->SetMouseReportingMode(InputTranslator::MouseReportingMode::UTF8);
        else
            m_InputTranslator->SetMouseReportingMode(InputTranslator::MouseReportingMode::Normal);
    }
}

void InterpreterImpl::RequestMouseEventsChanged()
{
    m_OnRequestedMouseEventsChanged(m_RequestedMouseEvents);
    UpdateMouseReporting();
}

} // namespace nc::term
