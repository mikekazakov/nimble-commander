// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Parser2Impl.h"
#include <Utility/OrthodoxMonospace.h>
#include <Habanero/CFPtr.h>
#include <Carbon/Carbon.h>
#include <CoreFoundation/CoreFoundation.h>
#include "TranslateMaps.h"
#include <charconv>

#include <iostream>

namespace nc::term {

Parser2Impl::Parser2Impl(const Params& _params):
    m_ErrorLog(_params.error_log)
{
    Reset();
}

Parser2Impl::~Parser2Impl()
{
}

void Parser2Impl::Reset()
{
    SwitchTo(EscState::Text);
}

std::vector<input::Command> Parser2Impl::Parse( Bytes _to_parse )
{
    for( auto c: _to_parse )
        EatByte( static_cast<unsigned char>(c) );
    FlushText();
    
    return std::move(m_Output);
}

void Parser2Impl::EatByte( unsigned char _byte )
{
    while( true ) {
        const auto state = m_EscState;
        const auto consume = m_SubStates[static_cast<int>(m_EscState)].consume;
        const bool consumed = (*this.*consume)(_byte);
        if( consumed ) {
            return;
        }
        else {
            assert( state != m_EscState ); // ensure that state has changed if a current refused 
        }  
    }
}

void Parser2Impl::SwitchTo(EscState _state)
{
    if( m_EscState != _state ) {
        (*this.*m_SubStates[static_cast<int>(m_EscState)].exit)();
        m_EscState = _state;
        (*this.*m_SubStates[static_cast<int>(_state)].enter)();
    }
}

void Parser2Impl::SSTextEnter() noexcept
{
    m_TextState.UTF16CharsStockLen = 0;
    m_TextState.UTF32Char = 0;
    m_TextState.UTF8Count = 0;    
}

void Parser2Impl::SSTextExit() noexcept
{
    FlushText();
}

bool Parser2Impl::SSTextConsume(unsigned char _byte) noexcept
{    
    const unsigned char c = _byte;    
    if( c < 32 ) {
        SwitchTo(EscState::Control);
        return false;
    }
    ConsumeNextUTF8TextChar( c );
    return true;
}

void Parser2Impl::ConsumeNextUTF8TextChar( unsigned char _byte )
{
    const unsigned char c = _byte;
    auto &ts = m_TextState;
    if(c > 0x7f) {
        if (ts.UTF8Count && (c&0xc0)==0x80) {
            ts.UTF32Char = (ts.UTF32Char<<6) | (c&0x3f);
            ts.UTF8Count--;
            if(ts.UTF8Count)
                return;
        }
        else {
            if ((c & 0xe0) == 0xc0) {
                ts.UTF8Count = 1;
                ts.UTF32Char = (c & 0x1f);
            }
            else if ((c & 0xf0) == 0xe0) {
                ts.UTF8Count = 2;
                ts.UTF32Char = (c & 0x0f);
            }
            else if ((c & 0xf8) == 0xf0) {
                ts.UTF8Count = 3;
                ts.UTF32Char = (c & 0x07);
            }
            else if ((c & 0xfc) == 0xf8) {
                ts.UTF8Count = 4;
                ts.UTF32Char = (c & 0x03);
            }
            else if ((c & 0xfe) == 0xfc) {
                ts.UTF8Count = 5;
                ts.UTF32Char = (c & 0x01);
            }
            else
                ts.UTF8Count = 0;
            return;
        }
    }
    else if (m_TranslateMap != nullptr && m_TranslateMap != g_TranslateMaps[0] ) {
        ts.UTF32Char = m_TranslateMap[c];
    }
    else {
        ts.UTF32Char = c;
    }
    
    if(ts.UTF16CharsStockLen < UTF16CharsStockSize) {
        if(ts.UTF32Char < 0x10000) // store directly as UTF16
            ts.UTF16CharsStock[ts.UTF16CharsStockLen++] = ts.UTF32Char;
        else if(ts.UTF16CharsStockLen + 1 < UTF16CharsStockSize ) { // store as UTF16 suggorate pairs
            ts.UTF16CharsStock[ts.UTF16CharsStockLen++] = 0xD800 + ((ts.UTF32Char - 0x010000) >> 10);
            ts.UTF16CharsStock[ts.UTF16CharsStockLen++] = 0xDC00 + ((ts.UTF32Char - 0x010000) & 0x3FF);
        }
    }
    ts.UTF32Char = 0;
    ts.UTF8Count = 0;
}

void Parser2Impl::FlushText()
{
    using namespace input;

    if( m_TextState.UTF16CharsStockLen == 0 )
        return;
    
    bool can_be_composed = false;
    for( size_t i = 0; i < m_TextState.UTF16CharsStockLen; ++i )
        // treat utf16 code units as unicode, which is not right,
        // but ok for this case, since we assume that >0xFFFF can't be composed
        if( oms::CanCharBeTheoreticallyComposed(m_TextState.UTF16CharsStock[i]) ) {
            can_be_composed = true;
            break;
        }
    
    int chars_len = m_TextState.UTF16CharsStockLen;

    if(can_be_composed) {
        auto str = nc::base::CFPtr<CFMutableStringRef>::adopt(
            CFStringCreateMutableWithExternalCharactersNoCopy(nullptr,
                                                              m_TextState.UTF16CharsStock.data(),
                                                              m_TextState.UTF16CharsStockLen,
                                                              UTF16CharsStockSize,
                                                              kCFAllocatorNull
                                                              )); 
        if( str ) {
            CFStringNormalize(str.get(), kCFStringNormalizationFormC);
            chars_len = (int)CFStringGetLength(str.get());
        }
    }
    
    UTF32Text payload;
    
    for(int i = 0; i < chars_len; ++i) {
        uint32_t c = 0;
        if( CFStringIsSurrogateHighCharacter(m_TextState.UTF16CharsStock[i]) ) {
            if(i + 1 < chars_len &&
               CFStringIsSurrogateLowCharacter(m_TextState.UTF16CharsStock[i+1]) ) {
                c = CFStringGetLongCharacterForSurrogatePair(m_TextState.UTF16CharsStock[i],
                    m_TextState.UTF16CharsStock[i+1]);
                ++i;
            }
        }
        else
            c = m_TextState.UTF16CharsStock[i];
        
//         TODO: if(wrapping_mode == ...) <- need to add this
//        if( m_Scr.CursorX() >= m_Scr.Width() && !oms::IsUnicodeCombiningCharacter(c) )
//        {
//            m_Scr.PutWrap();
//            CR();
//            LF();
//        }

//        if(m_InsertMode)
//            m_Scr.DoShiftRowRight(oms::WCWidthMin1(c));
        
//        m_Scr.PutCh(c);
        payload.characters.push_back(c);
    }
    
    m_TextState.UTF16CharsStockLen = 0;

    Command command;
    command.type = Type::text;
    command.payload = std::move(payload);
    m_Output.emplace_back( std::move(command) );
}

Parser2Impl::EscState Parser2Impl::GetEscState() const noexcept
{
    return m_EscState;
}

void Parser2Impl::LF() noexcept
{
    m_Output.emplace_back( input::Type::line_feed );
}

void Parser2Impl::HT() noexcept
{
    m_Output.emplace_back( input::Type::horizontal_tab, 1 );
}

void Parser2Impl::CR() noexcept
{
    m_Output.emplace_back( input::Type::carriage_return );
}

void Parser2Impl::BS() noexcept
{
    m_Output.emplace_back( input::Type::back_space );
}

void Parser2Impl::BEL() noexcept
{
    // TODO: + if title
    m_Output.emplace_back( input::Type::bell );
}

void Parser2Impl::RI() noexcept
{
    m_Output.emplace_back( input::Type::reverse_index );
}

void Parser2Impl::RIS() noexcept
{
    Reset();
    m_Output.emplace_back( input::Type::reset );
}

void Parser2Impl::DECSC() noexcept
{
    // TODO: save translation stuff
    m_Output.emplace_back( input::Type::save_state ); 
}

void Parser2Impl::DECRC() noexcept
{
    // TODO: restore translation stuff
    m_Output.emplace_back( input::Type::restore_state );
}

void Parser2Impl::LogMissedEscChar( unsigned char _c )
{
    if( m_ErrorLog ) {
        char buf[256];
        sprintf(buf, "Missed an Esc char: %d(\'%c\')\n", (int)_c, _c);
        m_ErrorLog(buf);
    }
}

void Parser2Impl::SSEscEnter() noexcept
{
}

void Parser2Impl::SSEscExit() noexcept
{
}

bool Parser2Impl::SSEscConsume(unsigned char _byte) noexcept
{
    const unsigned char c = _byte;

    SwitchTo(EscState::Text);
    switch (c) {
        case '[': SwitchTo(EscState::CSI); return true;
        case ']': SwitchTo(EscState::OSC); return true;
            //                case '(': m_EscState = EscState::SetG0;         return;
            //                case ')': m_EscState = EscState::SetG1;         return;
        case '>':  /* Numeric keypad - ignoring now */  return true;
        case '=':  /* Appl. keypad - ignoring now */    return true;
            
            /* DECSC – Save Cursor (DEC Private)
             ESC 7     
             This sequence causes the cursor position, graphic rendition, and character set
             to be saved. */                
        case '7': DECSC(); return true;
            
            /* DECRC – Restore Cursor (DEC Private)
             ESC 8     
             This sequence causes the previously saved cursor position, graphic rendition,
             and character set to be restored. */
        case '8': DECRC(); return true;
            
            /*  NEL – Next Line
             ESC E     
             This sequence causes the active position to move to the first position on the
             next line downward. If the active position is at the bottom margin, a scroll up
             is performed. */
        case 'E': CR(); LF(); return true;
            
            /* IND – Index
             ESC D     
             This sequence causes the active position to move downward one line without
             changing the column position. If the active position is at the bottom margin, a
             scroll up is performed. */                     
        case 'D': LF(); return true;
            
            /* RI – Reverse Index
             ESC M     
             Move the active position to the same horizontal position on the preceding line.
             If the active position is at the top margin, a scroll down is performed. */                                
        case 'M': RI(); return true;
            
            /* RIS – Reset To Initial State
             ESC c     
             Reset the VT100 to its initial state, i.e., the state it has after it is
             powered on. */                                
        case 'c': RIS(); return true;
            
            // For everything else, i.e. unimplemented stuff - complain in a log.
        default: LogMissedEscChar(c); return true;
    }
    
//               
//           case EState::RightBr:
//               switch (c)
//               {
//                   case '0':
//                   case '1':
//                   case '2':
//                       m_TitleType = c - '0';
//                       m_EscState = EState::TitleSemicolon;
//                       return;
//                   case 'P':
//                       m_EscState = EState::Normal;
//                       return;
//                   case 'R':
//                       m_EscState = EState::Normal;
//                   default: printf("non-std right br char: %d(\'%c\')\n", (int)c, c);
//               }
//               
//               m_EscState = EState::Normal;
//               return;
//               
//           case EState::TitleSemicolon:
//               if( c==';' ) {
//                   m_EscState = EState::TitleBuf;
//                   m_Title.clear();
//               }
//               else if( c == '1' )
//                   // I have no idea why the on earth VIM on 10.13 uses this weird format, but it does:
//                   // ESC ] 1 1 ; title BELL
//                   return;
//               else
//                   m_EscState = EState::Normal;
//               return;
//               
//           case EState::TitleBuf:
//               m_Title += c;
//               return;
//               
//           case EState::LeftBr:
//               memset(m_Params, 0, sizeof(m_Params));
//               m_ParamsCnt = 0;
//               m_EscState = EState::ProcParams;
//               m_ParsingParamNow = false;
//               m_QuestionFlag = false;
//               if(c == '?') {
//                   m_QuestionFlag = true;
//                   return;
//               }
//                    
//           case EState::ProcParams:
//               if(c == '>') {
//                   // modifier '>' is somehow related with alternative screen, ignore now
//                   return;
//               }
//               
//               if(c == ';' && m_ParamsCnt < m_ParamsSize - 1) {
//                   m_ParamsCnt++;
//                   return;
//               } else if( c >= '0' && c <= '9' ) {
//                   m_ParsingParamNow = true;
//                   m_Params[m_ParamsCnt] *= 10;
//                   m_Params[m_ParamsCnt] += c - '0';
//                   return;
//               } else
//                   m_EscState = EState::GotParams;
//
//           case EState::GotParams:
//               if(m_ParsingParamNow) {
//                   m_ParsingParamNow = false;
//                   m_ParamsCnt++;
//               }
//               
//               m_EscState = EState::Normal;
//               switch(c) {
//                   case 'h': CSI_DEC_PMS(true);  return;
//                   case 'l': CSI_DEC_PMS(false); return;
//                   case 'A': CSI_A(); return;
//                   case 'B': case 'e': CSI_B(); return;
//                   case 'C': case 'a': CSI_C(); return;
//                   case 'd': CSI_d(); return;
//                   case 'D': CSI_D(); return;
//                   case 'H': case 'f': CSI_H(); return;
//                   case 'G': case '`': CSI_G(); return;
//                   case 'J': CSI_J(); return;
//                   case 'K': CSI_K(); return;
//                   case 'L': CSI_L(); return;
//                   case 'm': CSI_m(); return;
//                   case 'M': CSI_M(); return;
//                   case 'P': CSI_P(); return;
//                   case 'S': CSI_S(); return;
//                   case 'T': CSI_T(); return;
//                   case 'X': CSI_X(); return;
//                   case 's': EscSave(); return;
//                   case 'u': EscRestore(); return;
//                   case 'r': CSI_r(); return;
//                   case '@': CSI_At(); return;
//                   case 'c': CSI_c(); return;
//                   case 'n': CSI_n(); return;
//                   case 't': CSI_t(); return;
//                   default: CSI_Unknown(c); return;
//               }
//           
//           case EState::SetG0:
//               if (c == '0')       m_State[0].g0_charset  = TranslateMaps::Graph;
//               else if (c == 'B')  m_State[0].g0_charset  = TranslateMaps::Lat1;
//               else if (c == 'U')  m_State[0].g0_charset  = TranslateMaps::IBMPC;
//               else if (c == 'K')  m_State[0].g0_charset  = TranslateMaps::User;
//               SetTranslate(m_State[0].charset_no == 0 ? m_State[0].g0_charset : m_State[0].g1_charset);
//               return;
//               
//           case EState::SetG1:
//               if (c == '0')       m_State[0].g1_charset  = TranslateMaps::Graph;
//               else if (c == 'B')  m_State[0].g1_charset  = TranslateMaps::Lat1;
//               else if (c == 'U')  m_State[0].g1_charset  = TranslateMaps::IBMPC;
//               else if (c == 'K')  m_State[0].g1_charset  = TranslateMaps::User;
//               SetTranslate(m_State[0].charset_no == 0 ? m_State[0].g0_charset : m_State[0].g1_charset);
//               return;
               
//        case EscState::Normal:
//              ConsumeNextUTF8TextChar( c );
//        default:
//            break;
//       }
    return true;
}

void Parser2Impl::SSControlEnter() noexcept
{
}

void Parser2Impl::SSControlExit() noexcept
{
}

bool Parser2Impl::SSControlConsume(unsigned char _byte) noexcept
{
    const unsigned char c = _byte;        
    if( c < 32 ) {
        switch (c) {
            case  0: SwitchTo(EscState::Text); return true;
            case  1: SwitchTo(EscState::Text); return true;
            case  2: SwitchTo(EscState::Text); return true;
            case  3: SwitchTo(EscState::Text); return true;
            case  4: SwitchTo(EscState::Text); return true;
            case  5: SwitchTo(EscState::Text); return true;
            case  6: SwitchTo(EscState::Text); return true;
            case  7: SwitchTo(EscState::Text); BEL(); return true;
            case  8: SwitchTo(EscState::Text); BS(); return true;
            case  9: SwitchTo(EscState::Text); HT(); return true;
            case 10:
            case 11:
            case 12: SwitchTo(EscState::Text); LF(); return true;
            case 13: SwitchTo(EscState::Text); CR(); return true;
            case 14: SwitchTo(EscState::Text); return true; // switch to g1
            case 15: SwitchTo(EscState::Text); return true; // switch to g2
            case 16: SwitchTo(EscState::Text); return true;
            case 17: SwitchTo(EscState::Text); return true; // xon
            case 18: SwitchTo(EscState::Text); return true;
            case 19: SwitchTo(EscState::Text); return true; // xoff
            case 20: SwitchTo(EscState::Text); return true;
            case 21: SwitchTo(EscState::Text); return true;
            case 22: SwitchTo(EscState::Text); return true;
            case 23: SwitchTo(EscState::Text); return true;
            case 24: SwitchTo(EscState::Text); return true;
            case 25: SwitchTo(EscState::Text); return true;
            case 26: SwitchTo(EscState::Text); return true;
            case 27: SwitchTo(EscState::Esc); return true;
            case 28: SwitchTo(EscState::Text); return true;
            case 29: SwitchTo(EscState::Text); return true;
            case 30: SwitchTo(EscState::Text); return true;
            case 31: SwitchTo(EscState::Text); return true;
        }
    }
    SwitchTo(EscState::Text);
    return false;
}

void Parser2Impl::SSOSCEnter() noexcept
{
    m_OSCState.buffer.clear();
    m_OSCState.got_esc = false;
}

void Parser2Impl::SSOSCExit() noexcept
{
    SSOSCSubmit();
}

bool Parser2Impl::SSOSCConsume(const unsigned char _byte) noexcept
{
    // consume the following (OSC was already consumed):
    // OSC Ps ; Pt BEL
    // OSC Ps ; Pt ST
    if( m_OSCState.got_esc ) { 
        if( _byte != '\\' ) {
            SSOSCDiscard();
        }            
        SwitchTo(EscState::Text);
    }
    else {
        if( _byte >= 32 ) {
            m_OSCState.buffer += _byte;
        }
        else {
            if( _byte == '\x07' ) {
                SwitchTo(EscState::Text);
            }
            else if( _byte == '\x1B' ) {
                m_OSCState.got_esc = true;
            }
            else {
                SSOSCDiscard();
                SwitchTo(EscState::Text);
            }
        }
    }
    return true;
}

void Parser2Impl::SSOSCDiscard() noexcept
{
    m_OSCState.buffer.clear();
}

// https://invisible-island.net/xterm/ctlseqs/ctlseqs.html -> Operating System Commands
void Parser2Impl::SSOSCSubmit() noexcept
{
    // parse the following format: Ps ; Pt
    std::string_view s = m_OSCState.buffer;
    auto sc_pos = s.find(';');
    if( sc_pos == s.npos )
        return;
    const std::string_view pt = s.substr(sc_pos + 1);        

    unsigned ps = std::numeric_limits<unsigned>::max();    
    if( std::from_chars(s.data(), s.data() + sc_pos, ps).ec != std::errc() )
        return;
    
    using namespace input;
    // currently the parser ignores any OSC other than 0, 1, 3.    
    if( ps == 0 ) {
        // Ps = 0  ⇒  Change Icon Name and Window Title to Pt.
        m_Output.emplace_back( Type::change_title, Title{Title::IconAndWindow, std::string(pt)});
    }
    else if( ps == 1 ) {
        // Ps = 1  ⇒  Change Icon Name to Pt.
        m_Output.emplace_back( Type::change_title, Title{Title::Icon, std::string(pt)});
    }
    else if( ps == 2 ) {
        // Ps = 2  ⇒  Change Window Title to Pt.
        m_Output.emplace_back( Type::change_title, Title{Title::Window, std::string(pt)});
    }
    else {
        LogMissedOSCRequest(ps, pt);
    }
}

void Parser2Impl::LogMissedOSCRequest( unsigned _ps, std::string_view _pt )
{
    if( m_ErrorLog ) {
        using namespace std::string_literals;
        auto msg = "Missed an OSC: "s + std::to_string(_ps) + ": "s + std::string(_pt);
        m_ErrorLog( msg );
    }
}

void Parser2Impl::SSCSIEnter() noexcept
{
    m_CSIState.buffer.clear();
}

void Parser2Impl::SSCSIExit() noexcept
{
    SSCSISubmit();
}

constexpr static std::array<bool, 256> CSI_Table( std::string_view _on )
{
    std::array<bool, 256> flags{};
    std::fill(flags.begin(), flags.end(), false);
    for( auto c: _on )
        flags[(unsigned char)c] = true;
    return flags;
}

constexpr static std::array<bool, 256> g_CSI_ValidTerminal = 
    CSI_Table("@ABCDEFGHIJKLMPSTXZ^`abcdefghilmnpqrstuvwxyz{|}~");

constexpr static std::array<bool, 256> g_CSI_ValidContents =
    CSI_Table("01234567890; ?>=!\"\'$#*");

bool Parser2Impl::SSCSIConsume(unsigned char _byte) noexcept
{
    if( g_CSI_ValidContents[_byte] ) {
        m_CSIState.buffer += static_cast<char>(_byte);
        return true;
    }
    else {
        if( g_CSI_ValidTerminal[_byte] ) {
            m_CSIState.buffer += static_cast<char>(_byte);
            SwitchTo(EscState::Text);
            return true;
        }
        else {            
            m_CSIState.buffer.clear(); // discard
            SwitchTo(EscState::Text);
            return false;
        }
    }
}

void Parser2Impl::SSCSISubmit() noexcept
{
    if( m_CSIState.buffer.empty() )
        return;

    const auto c = m_CSIState.buffer.back();
    switch( c ) {
        case 'A': CSI_A(); break;
        case 'B': CSI_B(); break;
        case 'C': CSI_C(); break;
        case 'D': CSI_D(); break;
        case 'E': CSI_E(); break;
        case 'F': CSI_F(); break;
        case 'G': CSI_G(); break;
        case 'H': CSI_H(); break;
        case 'I': CSI_I(); break;
        case 'J': CSI_J(); break;
        case 'K': CSI_K(); break;
        case 'L': CSI_L(); break;
        case 'M': CSI_M(); break;
        case 'P': CSI_P(); break;
        case 'S': CSI_S(); break;
        case 'T': CSI_T(); break;
        case 'X': CSI_X(); break;
        case 'Z': CSI_Z(); break;
        case 'a': CSI_a(); break;
        case 'b': CSI_b(); break;
        case '`': CSI_Accent(); break;
        default: break;
    } 
}

    //               m_EscState = EState::Normal;
    //               switch(c) {
    //                   case 'h': CSI_DEC_PMS(true);  return;
    //                   case 'l': CSI_DEC_PMS(false); return;
    //                   case 'd': CSI_d(); return;
    //                   case 'm': CSI_m(); return;
    //                   case 's': EscSave(); return;
    //                   case 'u': EscRestore(); return;
    //                   case 'r': CSI_r(); return;
    //                   case '@': CSI_At(); return;
    //                   case 'c': CSI_c(); return;
    //                   case 'n': CSI_n(); return;
    //                   case 't': CSI_t(); return;
    //                   default: CSI_Unknown(c); return;
    //               }

void Parser2Impl::CSI_A() noexcept
{
//    CSI Ps A - Cursor Up Ps Times (default = 1) (CUU).
//    Not implemented:
//    CSI Ps SP A - Shift right Ps columns(s) (default = 1) (SR), ECMA-48.

    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    
    input::CursorMovement cm;
    cm.positioning = input::CursorMovement::Relative;
    cm.x = 0;
    cm.y = -static_cast<int>(ps);
    m_Output.emplace_back( input::Type::move_cursor, cm );
}

void Parser2Impl::CSI_B() noexcept
{
//  CSI Ps B  Cursor Down Ps Times (default = 1) (CUD).
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    
    input::CursorMovement cm;
    cm.positioning = input::CursorMovement::Relative;
    cm.x = 0;
    cm.y = static_cast<int>(ps);
    m_Output.emplace_back( input::Type::move_cursor, cm );    
}

void Parser2Impl::CSI_C() noexcept
{
// CSI Ps C  Cursor Forward Ps Times (default = 1) (CUF).
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    
    input::CursorMovement cm;
    cm.positioning = input::CursorMovement::Relative;
    cm.x = static_cast<int>(ps);
    cm.y = 0;
    m_Output.emplace_back( input::Type::move_cursor, cm );
}

void Parser2Impl::CSI_D() noexcept
{
// CSI Ps D  Cursor Backward Ps Times (default = 1) (CUB).
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    
    input::CursorMovement cm;
    cm.positioning = input::CursorMovement::Relative;
    cm.x = -static_cast<int>(ps);
    cm.y = 0;
    m_Output.emplace_back( input::Type::move_cursor, cm );
}

void Parser2Impl::CSI_E() noexcept
{
// CSI Ps E  Cursor Next Line Ps Times (default = 1) (CNL).
// E   CNL       Move cursor down the indicated # of rows, to column 1.
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    
    input::CursorMovement cm;
    cm.positioning = input::CursorMovement::Relative;
    cm.x.reset();
    cm.y = static_cast<int>(ps);
    m_Output.emplace_back( input::Type::move_cursor, cm );
    
    cm.positioning = input::CursorMovement::Absolute;
    cm.x = 0;
    cm.y.reset();
    m_Output.emplace_back( input::Type::move_cursor, cm );
}
    
void Parser2Impl::CSI_F() noexcept
{
// CSI Ps F  Cursor Preceding Line Ps Times (default = 1) (CPL).
// F   CPL       Move cursor up the indicated # of rows, to column 1.
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    
    input::CursorMovement cm;
    cm.positioning = input::CursorMovement::Relative;
    cm.x.reset();
    cm.y = -static_cast<int>(ps);
    m_Output.emplace_back( input::Type::move_cursor, cm );
    
    cm.positioning = input::CursorMovement::Absolute;
    cm.x = 0;
    cm.y.reset();
    m_Output.emplace_back( input::Type::move_cursor, cm );
}
    
void Parser2Impl::CSI_G() noexcept
{
//CSI Ps G  Cursor Character Absolute  [column] (default = [row,1]) (CHA).
    int x = 0;
    const auto p = CSIParamsScanner::Parse(m_CSIState.buffer);
    if( p.count >= 1 )
        x = p.values[0] > 0 ? p.values[0] - 1 : 0; 
    input::CursorMovement cm;
    cm.positioning = input::CursorMovement::Absolute;
    cm.x = x;
    m_Output.emplace_back( input::Type::move_cursor, cm );   
}

void Parser2Impl::CSI_H() noexcept
{
//    CSI Ps ; Ps H
//    Cursor Position [row;column] (default = [1,1]) (CUP).
    int x = 0;
    int y = 0;
    const auto p = CSIParamsScanner::Parse(m_CSIState.buffer);
    if( p.count == 2 ) {
        y = p.values[0] > 0 ? p.values[0] - 1 : 0; 
        x = p.values[1] > 0 ? p.values[1] - 1 : 0;
    }
    input::CursorMovement cm;
    cm.positioning = input::CursorMovement::Absolute;
    cm.x = x;
    cm.y = y;
    m_Output.emplace_back( input::Type::move_cursor, cm );    
}
    
void Parser2Impl::CSI_I() noexcept
{
// CSI Ps I  Cursor Forward Tabulation Ps tab stops (default = 1) (CHT).
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    m_Output.emplace_back( input::Type::horizontal_tab, static_cast<int>(ps) );
}
    
void Parser2Impl::CSI_J() noexcept
{
//    CSI Ps J  Erase in Display (ED), VT100.
//    Ps = 0  ⇒  Erase Below (default).
//    Ps = 1  ⇒  Erase Above.
//    Ps = 2  ⇒  Erase All.
//    Ps = 3  ⇒  Erase Saved Lines, xterm.
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 0; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    
    using input::DisplayErasure;
    DisplayErasure de;
    switch( ps ) {
        case 0:
            de.what_to_erase = DisplayErasure::Area::FromCursorToDisplayEnd;
            break;
        case 1:
            de.what_to_erase = DisplayErasure::Area::FromDisplayStartToCursor;
            break;
        case 2:
            de.what_to_erase = DisplayErasure::Area::WholeDisplay;
            break;
        case 3:
            de.what_to_erase = DisplayErasure::Area::WholeDisplayWithScrollback;
            break;
        default:
            return;
    };
    
    m_Output.emplace_back( input::Type::erase_in_display, de );
}

void Parser2Impl::CSI_K() noexcept
{
// CSI Ps K  Erase in Line (EL), VT100.
// Ps = 0  ⇒  Erase to Right (default).
// Ps = 1  ⇒  Erase to Left.
// Ps = 2  ⇒  Erase All.
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 0; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    
    using input::LineErasure;
    LineErasure le;
    switch( ps ) {
        case 0:
            le.what_to_erase = LineErasure::Area::FromCursorToLineEnd;
            break;
        case 1:
            le.what_to_erase = LineErasure::Area::FromLineStartToCursor;
            break;
        case 2:
            le.what_to_erase = LineErasure::Area::WholeLine;
            break;
        default:
            return;
    };
    
    m_Output.emplace_back( input::Type::erase_in_line, le );
}

void Parser2Impl::CSI_L() noexcept
{
// CSI Ps L  Insert Ps Line(s) (default = 1) (IL).
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    m_Output.emplace_back( input::Type::insert_lines, ps );
}

void Parser2Impl::CSI_M() noexcept
{
// CSI Ps M  Delete Ps Line(s) (default = 1) (DL).
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    m_Output.emplace_back( input::Type::delete_lines, ps );
}
    
void Parser2Impl::CSI_P() noexcept
{
// CSI Ps P  Delete Ps Character(s) (default = 1) (DCH).
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    m_Output.emplace_back( input::Type::delete_characters, ps );
}
    
void Parser2Impl::CSI_S() noexcept
{
// CSI Ps S  Scroll up Ps lines (default = 1) (SU), VT420, ECMA-48.
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    m_Output.emplace_back( input::Type::scroll_lines, static_cast<signed>(ps) );
}
    
void Parser2Impl::CSI_T() noexcept
{
// CSI Ps T  Scroll down Ps lines (default = 1) (SD), VT420.
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    m_Output.emplace_back( input::Type::scroll_lines, -static_cast<signed>(ps) );
}
    
void Parser2Impl::CSI_X() noexcept
{
// CSI Ps X  Erase Ps Character(s) (default = 1) (ECH).
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    m_Output.emplace_back( input::Type::erase_characters, ps );
}
    
void Parser2Impl::CSI_Z() noexcept
{
// CSI Ps Z  Cursor Backward Tabulation Ps tab stops (default = 1) (CBT).
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    m_Output.emplace_back( input::Type::horizontal_tab, -static_cast<int>(ps) );
}
    
void Parser2Impl::CSI_a() noexcept
{
// CSI Pm a  Character Position Relative  [columns] (default = [row,col+1]) (HPR).
    const std::string_view s = m_CSIState.buffer;
    int ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    input::CursorMovement cm;
    cm.positioning = input::CursorMovement::Relative;
    cm.x = ps;
    cm.y = std::nullopt;
    m_Output.emplace_back( input::Type::move_cursor, cm );
}
    
void Parser2Impl::CSI_b() noexcept
{
// CSI Ps b  Repeat the preceding graphic character Ps times (REP).
    const std::string_view s = m_CSIState.buffer;
    unsigned ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    m_Output.emplace_back( input::Type::repeat_last_character, ps );
}

void Parser2Impl::CSI_Accent() noexcept
{
// CSI Pm `  Character Position Absolute  [column] (default = [row,1]) (HPA).
    const std::string_view s = m_CSIState.buffer;
    int ps = 1; // default value
    std::from_chars(s.data(), s.data() + s.size(), ps);
    ps = std::max(ps - 1, 0);
    input::CursorMovement cm;
    cm.positioning = input::CursorMovement::Absolute;
    cm.x = ps;
    cm.y = std::nullopt;
    m_Output.emplace_back( input::Type::move_cursor, cm );
}
    
Parser2Impl::CSIParamsScanner::Params
Parser2Impl::CSIParamsScanner::Parse(std::string_view _csi) noexcept
{
    Params p;
    auto string = _csi;
    while( true ) {
        if( p.count == p.values.size() )
            break;    
        unsigned value = 0;
        auto result = std::from_chars(string.data(), string.data() + string.size(), value); 
        if( result.ec == std::errc{} ) {
            p.values[p.count++] = value;
            
            string.remove_prefix( result.ptr - string.data() );
            if( string.empty() || string.front() != ';' )
                break;
            string.remove_prefix(1);
        }
        else {
            break;
        }
    }
    return p;
} 

}
