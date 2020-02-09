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
    m_Output.emplace_back( input::Type::horizontal_tab );
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
            //                case '[': m_EscState = EscState::LeftBracket;   return;
        case ']': SwitchTo(EscState::OSC);  return true;
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
        // TODO: log
    }
}

}
