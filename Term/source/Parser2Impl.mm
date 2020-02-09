// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Parser2Impl.h"
#include <Utility/OrthodoxMonospace.h>
#include <Habanero/CFPtr.h>
#include <Carbon/Carbon.h>
#include <CoreFoundation/CoreFoundation.h>
#include "TranslateMaps.h"

namespace nc::term {

Parser2Impl::Parser2Impl(const Params& _params):
    m_ErrorLog(_params.error_log)
{
}

Parser2Impl::~Parser2Impl()
{
}

void Parser2Impl::Reset()
{
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
    const unsigned char c = _byte;
    
    if( c < 32 ) {
        FlushText();        
        switch (c) {
            case  0: return;
            case  1: return;
            case  2: return;
            case  3: return;
            case  4: return;
            case  5: return;
            case  6: return;
            case  7: BEL(); return;
            case  8: BS(); return;
            case  9: HT(); return;
            case 10:
            case 11:
            case 12: LF(); return;
            case 13: CR(); return;
            case 14: return; // switch to g1
            case 15: return; // switch to g2
            case 16: return;
            case 17: return; // xon
            case 18: return;
            case 19: return; // xoff
            case 20: return;
            case 21: return;
            case 22: return;
            case 23: return;
            case 24: m_EscState = EscState::Normal; return;
            case 25: return;
            case 26: m_EscState = EscState::Normal; return;
            case 27: m_EscState = EscState::Esc; return;
            case 28: return;
            case 29: return;
            case 30: return;
            case 31: return;
        }
    }

    switch (m_EscState) {
        case EscState::Esc:
            m_EscState = EscState::Normal;
            switch (c) {
                case '[': m_EscState = EscState::LeftBracket;   return;
                case ']': m_EscState = EscState::RightBracket;  return;
                case '(': m_EscState = EscState::SetG0;         return;
                case ')': m_EscState = EscState::SetG1;         return;
                case '>':  /* Numeric keypad - ignoring now */  return;
                case '=':  /* Appl. keypad - ignoring now */    return;
                                
                /* DECSC – Save Cursor (DEC Private)
                   ESC 7     
                   This sequence causes the cursor position, graphic rendition, and character set
                   to be saved. */                
                case '7': DECSC(); return;

                /* DECRC – Restore Cursor (DEC Private)
                   ESC 8     
                   This sequence causes the previously saved cursor position, graphic rendition,
                   and character set to be restored. */
                case '8': DECRC(); return;
                
                /*  NEL – Next Line
                    ESC E     
                    This sequence causes the active position to move to the first position on the
                    next line downward. If the active position is at the bottom margin, a scroll up
                    is performed. */
                case 'E': CR(); LF(); return;
                    
                /* IND – Index
                   ESC D     
                   This sequence causes the active position to move downward one line without
                   changing the column position. If the active position is at the bottom margin, a
                   scroll up is performed. */                     
                case 'D': LF(); return;

                /* RI – Reverse Index
                   ESC M     
                   Move the active position to the same horizontal position on the preceding line.
                   If the active position is at the top margin, a scroll down is performed. */                                
                case 'M': RI(); return;

                /* RIS – Reset To Initial State
                   ESC c     
                   Reset the VT100 to its initial state, i.e., the state it has after it is
                   powered on. */                                
                case 'c': RIS(); return;
                
                // For everything else, i.e. unimplemented stuff - complain in a log.
                default: LogMissedEscChar(c); return;
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
               
        case EscState::Normal:
              ConsumeNextUTF8TextChar( c );
        default:
            break;
       }
}

void Parser2Impl::ConsumeNextUTF8TextChar( unsigned char _byte )
{
    const unsigned char c = _byte;
    if(c > 0x7f) {
        if (m_UTF8Count && (c&0xc0)==0x80) {
            m_UTF32Char = (m_UTF32Char<<6) | (c&0x3f);
            m_UTF8Count--;
            if(m_UTF8Count)
                return;
        }
        else {
            if ((c & 0xe0) == 0xc0) {
                m_UTF8Count = 1;
                m_UTF32Char = (c & 0x1f);
            }
            else if ((c & 0xf0) == 0xe0) {
                m_UTF8Count = 2;
                m_UTF32Char = (c & 0x0f);
            }
            else if ((c & 0xf8) == 0xf0) {
                m_UTF8Count = 3;
                m_UTF32Char = (c & 0x07);
            }
            else if ((c & 0xfc) == 0xf8) {
                m_UTF8Count = 4;
                m_UTF32Char = (c & 0x03);
            }
            else if ((c & 0xfe) == 0xfc) {
                m_UTF8Count = 5;
                m_UTF32Char = (c & 0x01);
            }
            else
                m_UTF8Count = 0;
            return;
        }
    }
    else if (m_TranslateMap != nullptr && m_TranslateMap != g_TranslateMaps[0] ) {
        m_UTF32Char = m_TranslateMap[c];
    }
    else {
        m_UTF32Char = c;
    }
    
    if(m_UTF16CharsStockLen < UTF16CharsStockSize) {
        if(m_UTF32Char < 0x10000) // store directly as UTF16
            m_UTF16CharsStock[m_UTF16CharsStockLen++] = m_UTF32Char;
        else if(m_UTF16CharsStockLen + 1 < UTF16CharsStockSize ) { // store as UTF16 suggorate pairs
            m_UTF16CharsStock[m_UTF16CharsStockLen++] = 0xD800 + ((m_UTF32Char - 0x010000) >> 10);
            m_UTF16CharsStock[m_UTF16CharsStockLen++] = 0xDC00 + ((m_UTF32Char - 0x010000) & 0x3FF);
        }
    }
    m_UTF32Char = 0;
    m_UTF8Count = 0;
}

void Parser2Impl::FlushText()
{
    using namespace input;

    if( m_UTF16CharsStockLen == 0 )
        return;
    
    bool can_be_composed = false;
    for( size_t i = 0; i < m_UTF16CharsStockLen; ++i )
        // treat utf16 code units as unicode, which is not right,
        // but ok for this case, since we assume that >0xFFFF can't be composed
        if( oms::CanCharBeTheoreticallyComposed(m_UTF16CharsStock[i]) ) {
            can_be_composed = true;
            break;
        }
    
    int chars_len = m_UTF16CharsStockLen;

    if(can_be_composed) {
        auto str = nc::base::CFPtr<CFMutableStringRef>::adopt(
            CFStringCreateMutableWithExternalCharactersNoCopy(nullptr,
                                                              m_UTF16CharsStock.data(),
                                                              m_UTF16CharsStockLen,
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
        if( CFStringIsSurrogateHighCharacter(m_UTF16CharsStock[i]) ) {
            if(i + 1 < chars_len &&
               CFStringIsSurrogateLowCharacter(m_UTF16CharsStock[i+1]) ) {
                c = CFStringGetLongCharacterForSurrogatePair(m_UTF16CharsStock[i],
                    m_UTF16CharsStock[i+1]);
                ++i;
            }
        }
        else
            c = m_UTF16CharsStock[i];
        
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
    
    m_UTF16CharsStockLen = 0;

    Command command;
    command.type = Type::text;
    command.payload = std::move(payload);
    m_Output.emplace_back( std::move(command) );
}

Parser2Impl::EscState Parser2Impl::GetEscState() const noexcept
{
    return m_EscState;
}

void Parser2Impl::LF()
{
    m_Output.emplace_back( input::Type::line_feed );
}

void Parser2Impl::HT()
{
    m_Output.emplace_back( input::Type::horizontal_tab );
}

void Parser2Impl::CR()
{
    m_Output.emplace_back( input::Type::carriage_return );
}

void Parser2Impl::BS()
{
    m_Output.emplace_back( input::Type::back_space );
}

void Parser2Impl::BEL()
{
    // TODO: + if title
    m_Output.emplace_back( input::Type::bell );
}

void Parser2Impl::RI()
{
    m_Output.emplace_back( input::Type::reverse_index );
}

void Parser2Impl::RIS()
{
    Reset();
    m_Output.emplace_back( input::Type::reset );
}

void Parser2Impl::DECSC()
{
    // TODO: save translation stuff
    m_Output.emplace_back( input::Type::save_state ); 
}

void Parser2Impl::DECRC()
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

}
