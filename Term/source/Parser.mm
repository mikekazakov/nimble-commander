// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Carbon/Carbon.h>
#include <Utility/FontCache.h>
#include <Utility/OrthodoxMonospace.h>
#include "Parser.h"
#include "Screen.h"
#include "TranslateMaps.h"

namespace nc::term {

Parser::Parser(Screen &_scr, function<void(const void* _d, int _sz)> _task_input):
    m_Scr(_scr),
    m_TaskInput( move(_task_input) )
{
    Reset();
}

Parser::~Parser()
{
}

void Parser::Reset()
{
    m_Height = m_Scr.Height();
    m_Width = m_Scr.Width();
    
    memset(&m_State, 0, sizeof(m_State));
    m_State[0].fg_color = ScreenColors::Default;
    m_State[0].bg_color = ScreenColors::Default;
    m_State[0].g0_charset = TranslateMaps::Lat1;
    m_State[0].g1_charset = TranslateMaps::Graph;
    m_TitleType = 0;
    m_LineAbs = true;
    m_InsertMode = false;
    m_Top = 0;
    m_Bottom = m_Scr.Height();
    m_EscState = EState::Normal;
    m_ParamsCnt = 0;
    m_QuestionFlag = false;
    m_ParsingParamNow = 0;
    m_UTF32Char = 0;
    m_UTF8Count = 0;
    m_UTF16CharsStockLen = 0;
    m_DECPMS_SavedCurX = 0;
    m_DECPMS_SavedCurY = 0;
    
    
    SetTranslate(TranslateMaps::Lat1);
    UpdateAttrs();
    m_Scr.GoToDefaultPosition();
    EscSave();

    m_Title.clear();
    m_Scr.SetTitle("");
    
    m_Scr.SetAlternateScreen(false);

    m_TabStop[0]= 0x01010100;
    for(int i = 1; i < 16; ++i)
        m_TabStop[i] = 0x01010101;
}

void Parser::SetTaskScreenResize( function<void(int,int)> _callback )
{
    m_TaskScreenResizeCallback = _callback;
}

void Parser::Flush()
{
    if( m_UTF16CharsStockLen == 0 ) return;
    
    bool can_be_composed = false;
    for(int i = 0; i < m_UTF16CharsStockLen; ++i)
        // treat utf16 code units as unicode, which is not right, but ok for this case, since we assume that >0xFFFF can't be composed
        if(oms::CanCharBeTheoreticallyComposed(m_UTF16CharsStock[i])) {
            can_be_composed = true;
            break;
        }
    
    int chars_len = m_UTF16CharsStockLen;

    if(can_be_composed) {
        CFMutableStringRef str = CFStringCreateMutableWithExternalCharactersNoCopy (
                                                                              NULL,
                                                                              m_UTF16CharsStock,
                                                                              m_UTF16CharsStockLen,
                                                                              m_UTF16CharsStockSize,
                                                                              kCFAllocatorNull
                                                                              );
        if(str != NULL) {
            CFStringNormalize(str, kCFStringNormalizationFormC);
            chars_len = (int)CFStringGetLength(str);
            CFRelease(str);
        }
    }
    
    for(int i = 0; i < chars_len; ++i)
    {
        uint32_t c = 0;
        if(CFStringIsSurrogateHighCharacter(m_UTF16CharsStock[i])) {
            if(i + 1 < chars_len &&
               CFStringIsSurrogateLowCharacter(m_UTF16CharsStock[i+1]) ) {
                c = CFStringGetLongCharacterForSurrogatePair(m_UTF16CharsStock[i], m_UTF16CharsStock[i+1]);
                ++i;
            }
        }
        else
            c = m_UTF16CharsStock[i];
        
        // TODO: if(wrapping_mode == ...) <- need to add this
        if( m_Scr.CursorX() >= m_Scr.Width() && !oms::IsUnicodeCombiningCharacter(c) )
        {
            m_Scr.PutWrap();
            CR();
            LF();
        }

        if(m_InsertMode)
            m_Scr.DoShiftRowRight(oms::WCWidthMin1(c));
        
        m_Scr.PutCh(c);
    }
    
    m_UTF16CharsStockLen = 0;
}

int Parser::EatBytes(const unsigned char *_bytes, unsigned _sz)
{
    int all_flags = 0;
    for(int i = 0; i < _sz; ++i) {
        int flags = 0;
        
        EatByte(_bytes[i], flags);

        all_flags |= flags;
    }
    Flush();
    return all_flags;
}

void Parser::EatByte(unsigned char _byte, int &_result_flags)
{
    const unsigned char c = _byte;
    
    if(c < 32) Flush();
    
    switch (c) {
        case  0: return;
        case  7: if(m_EscState == EState::TitleBuf) {
                     m_Scr.SetTitle(m_Title.c_str());
                     m_EscState = EState::Normal;
                     _result_flags |= Result_ChangedTitle;
                     return;
                 }
                 NSBeep();
                 return;
        case  8: m_Scr.DoCursorLeft(); return;
        case  9: HT(); return;
        case 10:
        case 11:
        case 12: LF(); return;
        case 13: CR(); return;
        case 24:
        case 26: m_EscState = EState::Normal; return;
        case 27: m_EscState = EState::Esc; return;
        default: break;
    }
    
    switch (m_EscState) {
        case EState::Esc:
            m_EscState = EState::Normal;
            switch (c) {
                case '[': m_EscState = EState::LeftBr;    return;
                case ']': m_EscState = EState::RightBr;   return;
                case '(': m_EscState = EState::SetG0;     return;
                case ')': m_EscState = EState::SetG1;     return;
                case '>':  /* Numeric keypad - ignoring now */  return;
                case '=':  /* Appl. keypad - ignoring now */    return;
                case '7': EscSave();    return;
                case '8': EscRestore(); return;
                case 'E': CR();         return;
                case 'D': LF();         return;
                case 'M': RI();         return;
                case 'c': Reset();      return;
                default: printf("missed Esc char: %d(\'%c\')\n", (int)c, c); return;
            }
            
        case EState::RightBr:
            switch (c)
            {
                case '0':
                case '1':
                case '2':
                    m_TitleType = c - '0';
                    m_EscState = EState::TitleSemicolon;
                    return;
                case 'P':
                    m_EscState = EState::Normal;
                    return;
                case 'R':
                    m_EscState = EState::Normal;
                default: printf("non-std right br char: %d(\'%c\')\n", (int)c, c);
            }
            
            m_EscState = EState::Normal;
            return;
            
        case EState::TitleSemicolon:
            if( c==';' ) {
                m_EscState = EState::TitleBuf;
                m_Title.clear();
            }
            else if( c == '1' )
                // I have no idea why the on earth VIM on 10.13 uses this weird format, but it does:
                // ESC ] 1 1 ; title BELL
                return;
            else
                m_EscState = EState::Normal;
            return;
            
        case EState::TitleBuf:
            m_Title += c;
            return;
            
        case EState::LeftBr:
            memset(m_Params, 0, sizeof(m_Params));
            m_ParamsCnt = 0;
            m_EscState = EState::ProcParams;
            m_ParsingParamNow = false;
            m_QuestionFlag = false;
            if(c == '?') {
                m_QuestionFlag = true;
                return;
            }
                 
        case EState::ProcParams:
            if(c == '>') {
                // modifier '>' is somehow related with alternative screen, ignore now
                return;
            }
            
            if(c == ';' && m_ParamsCnt < m_ParamsSize - 1) {
                m_ParamsCnt++;
                return;
            } else if( c >= '0' && c <= '9' ) {
                m_ParsingParamNow = true;
                m_Params[m_ParamsCnt] *= 10;
                m_Params[m_ParamsCnt] += c - '0';
                return;
            } else
                m_EscState = EState::GotParams;

        case EState::GotParams:
            if(m_ParsingParamNow) {
                m_ParsingParamNow = false;
                m_ParamsCnt++;
            }
            
            m_EscState = EState::Normal;
            switch(c) {
                case 'h': CSI_DEC_PMS(true);  return;
                case 'l': CSI_DEC_PMS(false); return;
                case 'A': CSI_A(); return;
                case 'B': case 'e': CSI_B(); return;
                case 'C': case 'a': CSI_C(); return;
                case 'd': CSI_d(); return;
                case 'D': CSI_D(); return;
                case 'H': case 'f': CSI_H(); return;
                case 'G': case '`': CSI_G(); return;
                case 'J': CSI_J(); return;
                case 'K': CSI_K(); return;
                case 'L': CSI_L(); return;
                case 'm': CSI_m(); return;
                case 'M': CSI_M(); return;
                case 'P': CSI_P(); return;
                case 'S': CSI_S(); return;
                case 'T': CSI_T(); return;
                case 'X': CSI_X(); return;
                case 's': EscSave(); return;
                case 'u': EscRestore(); return;
                case 'r': CSI_r(); return;
                case '@': CSI_At(); return;
                case 'c': CSI_c(); return;
                case 'n': CSI_n(); return;
                default: printf("unhandled: CSI %c\n", c);
            }
            return;
        
        case EState::SetG0:
            if (c == '0')       m_State[0].g0_charset  = TranslateMaps::Graph;
            else if (c == 'B')  m_State[0].g0_charset  = TranslateMaps::Lat1;
            else if (c == 'U')  m_State[0].g0_charset  = TranslateMaps::IBMPC;
            else if (c == 'K')  m_State[0].g0_charset  = TranslateMaps::User;
            SetTranslate(m_State[0].charset_no == 0 ? m_State[0].g0_charset : m_State[0].g1_charset);
            return;
            
        case EState::SetG1:
            if (c == '0')       m_State[0].g1_charset  = TranslateMaps::Graph;
            else if (c == 'B')  m_State[0].g1_charset  = TranslateMaps::Lat1;
            else if (c == 'U')  m_State[0].g1_charset  = TranslateMaps::IBMPC;
            else if (c == 'K')  m_State[0].g1_charset  = TranslateMaps::User;
            SetTranslate(m_State[0].charset_no == 0 ? m_State[0].g0_charset : m_State[0].g1_charset);
            return;
            
        case EState::Normal:
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
            else if (m_TranslateMap != 0 && m_TranslateMap != g_TranslateMaps[0] ) {
//                if (toggle_meta)
//                    c|=0x80;
                m_UTF32Char = m_TranslateMap[c];
            }
            else {
                m_UTF32Char = c;
            }
            
            if(m_UTF16CharsStockLen < m_UTF16CharsStockSize) {
                if(m_UTF32Char < 0x10000) // store directly as UTF16
                    m_UTF16CharsStock[m_UTF16CharsStockLen++] = m_UTF32Char;
                else if(m_UTF16CharsStockLen + 1 < m_UTF16CharsStockSize ) { // store as UTF16 suggorate pairs
                        m_UTF16CharsStock[m_UTF16CharsStockLen++] = 0xD800 + ((m_UTF32Char - 0x010000) >> 10);
                        m_UTF16CharsStock[m_UTF16CharsStockLen++] = 0xDC00 + ((m_UTF32Char - 0x010000) & 0x3FF);
                }
            }
            
            return;            
    }
}

void Parser::SetTranslate(unsigned char _charset)
{
    if(_charset < 0 || _charset >= 4)
        m_TranslateMap = g_TranslateMaps[0];
    m_TranslateMap = g_TranslateMaps[_charset];
}

void Parser::CSI_J()
{
    m_Scr.DoEraseScreen(m_Params[0]);
}

void Parser::CSI_A()
{
    m_Scr.DoCursorUp( m_ParamsCnt >= 1 ? m_Params[0] : 1 );
}

void Parser::CSI_B()
{
    m_Scr.DoCursorDown( m_ParamsCnt >= 1 ? m_Params[0] : 1 );
}

void Parser::CSI_C()
{
    m_Scr.DoCursorRight( m_ParamsCnt >= 1 ? m_Params[0] : 1 );
}

void Parser::CSI_D()
{
    m_Scr.DoCursorLeft( m_ParamsCnt >= 1 ? m_Params[0] : 1 );
}

void Parser::CSI_G()
{
    m_Params[0]--;
    m_Scr.GoTo(m_Params[0], m_Scr.CursorY());
}

void Parser::CSI_d()
{
    m_Params[0]--;
    DoGoTo(m_Scr.CursorX(), m_Params[0]);
}

void Parser::CSI_H()
{
    m_Params[0]--;
    m_Params[1]--;
    DoGoTo(m_Params[1], m_Params[0]);
}

void Parser::CSI_K()
{
    m_Scr.EraseInLine(m_Params[0]);
}

void Parser::CSI_X()
{
    if(m_Params[0] == 0)
        m_Params[0]++;
    m_Scr.EraseInLineCount(m_Params[0]);
}

void Parser::CSI_M()
{
    unsigned n = m_Params[0];
    if(n > m_Scr.Height() - m_Scr.CursorY())
        n = m_Scr.Height() - m_Scr.CursorY();
    else if(n == 0)
        n = 1;
    m_Scr.DoScrollUp(m_Scr.CursorY(), m_Bottom, n);
}

void Parser::CSI_c()
{
    // reporting our id as VT102
    const auto myid = "\033[?6c";
    if( !m_Params[0] )
        WriteTaskInput(myid);
}

void Parser::CSI_n()
{
    if( m_Params[0] == 3 ) {
        const auto valid_status = "\033[?0n";
        WriteTaskInput(valid_status);
    }
    else if( m_Params[0] == 6 ) {
        char buf[64];
        sprintf(buf,
                "\033[?%d;%dR",
                (m_LineAbs ? m_Scr.CursorY() : m_Scr.CursorY() - m_Top) + 1,
                m_Scr.CursorX() + 1
                );
        WriteTaskInput(buf);
    }
}

void Parser::SetDefaultAttrs()
{
    m_State[0].fg_color = ScreenColors::Default;
    m_State[0].bg_color = ScreenColors::Default;
    m_State[0].intensity = false;
    m_State[0].underline = false;
    m_State[0].reverse = false;
}

void Parser::UpdateAttrs()
{
    m_Scr.SetFgColor(m_State[0].fg_color);
    m_Scr.SetBgColor(m_State[0].bg_color);
    m_Scr.SetIntensity(m_State[0].intensity);
    m_Scr.SetUnderline(m_State[0].underline);
    m_Scr.SetReverse(m_State[0].reverse);
}

void Parser::CSI_m()
{
    if(m_ParamsCnt == 0) {
        SetDefaultAttrs();
        UpdateAttrs();
    }
    
    for(int i = 0; i < m_ParamsCnt; ++i)
        switch (m_Params[i]) {
            case 0:  SetDefaultAttrs(); UpdateAttrs(); break;
			case 1:
            case 21:
            case 22: m_Scr.SetIntensity(m_State[0].intensity = true);  break;
			case 2:  m_Scr.SetIntensity(m_State[0].intensity = false); break;
			case 4:  m_Scr.SetUnderline(m_State[0].underline = true);  break;
			case 24: m_Scr.SetUnderline(m_State[0].underline = false); break;
            case 7:  m_Scr.SetReverse(m_State[0].reverse = true);      break;
            case 27: m_Scr.SetReverse(m_State[0].reverse = false);     break;
            case 30: m_Scr.SetFgColor(m_State[0].fg_color = ScreenColors::Black);   break;
            case 31: m_Scr.SetFgColor(m_State[0].fg_color = ScreenColors::Red);     break;
            case 32: m_Scr.SetFgColor(m_State[0].fg_color = ScreenColors::Green);   break;
            case 33: m_Scr.SetFgColor(m_State[0].fg_color = ScreenColors::Yellow);  break;
            case 34: m_Scr.SetFgColor(m_State[0].fg_color = ScreenColors::Blue);    break;
            case 35: m_Scr.SetFgColor(m_State[0].fg_color = ScreenColors::Magenta); break;
            case 36: m_Scr.SetFgColor(m_State[0].fg_color = ScreenColors::Cyan);    break;
            case 37: m_Scr.SetFgColor(m_State[0].fg_color = ScreenColors::White);   break;
            case 40: m_Scr.SetBgColor(m_State[0].bg_color = ScreenColors::Black);   break;
            case 41: m_Scr.SetBgColor(m_State[0].bg_color = ScreenColors::Red);     break;
            case 42: m_Scr.SetBgColor(m_State[0].bg_color = ScreenColors::Green);   break;
            case 43: m_Scr.SetBgColor(m_State[0].bg_color = ScreenColors::Yellow);  break;
            case 44: m_Scr.SetBgColor(m_State[0].bg_color = ScreenColors::Blue);    break;
            case 45: m_Scr.SetBgColor(m_State[0].bg_color = ScreenColors::Magenta); break;
            case 46: m_Scr.SetBgColor(m_State[0].bg_color = ScreenColors::Cyan);    break;
            case 47: m_Scr.SetBgColor(m_State[0].bg_color = ScreenColors::White);   break;
            case 39: m_Scr.SetFgColor(m_State[0].fg_color = ScreenColors::Default); m_Scr.SetUnderline(m_State[0].underline = false); break;
			case 49: m_Scr.SetBgColor(m_State[0].bg_color = ScreenColors::Default); break;
            case  5: break; /* Blink: Slow  - less than 150 per minute*/
            case  6: break; /* Blink: Rapid - MS-DOS ANSI.SYS; 150 per minute or more; not widely supported*/
            case 25: break; /* Blink: off */
            case 90:
            case 91:
            case 92:
            case 93:
            case 94:
            case 95:
            case 96:
            case 97:
            case 98:
            case 99: break; /* Set foreground text color, high intensity	aixterm (not in standard) */
            case 100:
            case 101:
            case 102:
            case 103:
            case 104:
            case 105:
            case 106:
            case 107:
            case 108:
            case 109: break; /* Set background color, high intensity	aixterm (not in standard) */
            // [...] MANY MORE HERE
            default: printf("unhandled CSI_n_m: %d\n", m_Params[i]);
        }
}

void Parser::CSI_DEC_PMS(bool _on)
{
    for(int i = 0; i < m_ParamsCnt; ++i)
        if( m_QuestionFlag )
            switch( m_Params[i] ) { /* DEC private modes set/reset */
                case 1:			/* Cursor keys send ^[Ox/^[[x */
                    /*NOT YET IMPLEMENTED*/
                    break;
                case 6:			/* Origin relative/absolute */
                    m_LineAbs = !_on;
                    DoGoTo(0, 0);
                    break;
                case 7:			/* Autowrap on/off */
                    /*NOT YET IMPLEMENTED*/
                    break;
                case 12:        /* Cursor on/off */
                    /*NOT YET IMPLEMENTED*/
                    break;
                case 25:
                    /*NOT YET IMPLEMENTED*/
                    break;
				case 47: // alternate screen buffer mode
					if(_on) m_Scr.SaveScreen();
					else    m_Scr.RestoreScreen();
                    m_Scr.SetAlternateScreen(_on);
					break;
                case 1048:
                    if( _on ) {
                        m_DECPMS_SavedCurX = m_Scr.CursorX();
                        m_DECPMS_SavedCurY = m_Scr.CursorY();
                    }
                    else
                        m_Scr.GoTo(m_DECPMS_SavedCurX, m_DECPMS_SavedCurY);
                    break;
                case 1049:
                    // NB!
                    // be careful here: for some reasons some implementations use different save/restore path, not
                    // conventional EscSave/EscRestore. may cause a side-effect.
                    if( _on ) {
                        EscSave();
                        m_Scr.SaveScreen();
                        m_Scr.DoEraseScreen(2);
                    }
                    else {
                        EscRestore();
                        m_Scr.RestoreScreen();
                    }
                    m_Scr.SetAlternateScreen(_on);
                    break;
                case 1002:
                case 1003:
                case 1005:
                case 1006:
                case 1015:
                    // mouse stuff is not implemented
                    break;
                    
                case 1034:
                    // ignore meta mode for now, need to implement
                    // 1034:
                    // rmm     mo      End meta mode
                    // smm     mm      Begin meta mode (8th bit set)
                    break;
                    
                default:
                    printf("unhandled CSI_DEC_PMS?: %d on:%d\n", m_Params[i], (int)_on);
            }
        else
            switch (m_Params[i]) { /* ANSI modes set/reset */
                case 4:			/* Insert Mode on/off */
                    m_InsertMode = _on;
                    break;
                default:
                    printf("unhandled CSI_DEC_PMS: %d on:%d\n", m_Params[i], (int)_on);
            }
}

void Parser::PushRawTaskInput(NSString *_str)
{
    if(!_str || _str.length == 0)
        return;
    
    const char* utf8str = [_str UTF8String];
    size_t sz = strlen(utf8str);

    m_TaskInput(utf8str, (int)sz);
}

/**
 * That's a hacky implementation, it mimicks the real deadKeyState.
 * This can serve for purposes of decoding a single option-modified keypress, but can't be used for double keys decoding
 */
static CFStringRef CreateModifiedCharactersForKeyPress(unsigned short _keycode, NSEventModifierFlags _flags)
{
    // http://stackoverflow.com/questions/12547007/convert-key-code-into-key-equivalent-string
    // http://stackoverflow.com/questions/8263618/convert-virtual-key-code-to-unicode-string
    // http://stackoverflow.com/questions/22566665/how-to-capture-unicode-from-key-events-without-an-nstextview
    
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData = (CFDataRef)TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
    const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
    const UInt8 kbdType = LMGetKbdType();
    const UInt32 modifierKeyState = (_flags >> 16) & 0xFF;
    
    UInt32 deadKeyState = 0;
    const size_t unicodeStringLength = 4;
    UniChar unicodeString[unicodeStringLength];
    UniCharCount realLength;
    
    UCKeyTranslate(keyboardLayout,
                   _keycode,
                   kUCKeyActionDown,
                   modifierKeyState,
                   kbdType,
                   0,
                   &deadKeyState,
                   unicodeStringLength,
                   &realLength,
                   unicodeString);
    UCKeyTranslate(keyboardLayout,
                   _keycode,
                   kUCKeyActionDown,
                   modifierKeyState,
                   kbdType,
                   0,
                   &deadKeyState,
                   unicodeStringLength,
                   &realLength,
                   unicodeString);
    CFRelease(currentKeyboard);
    return CFStringCreateWithCharacters(kCFAllocatorDefault, unicodeString, realLength);
}

void Parser::ProcessKeyDown(NSEvent *_event)
{
    NSString* character = _event.charactersIgnoringModifiers;
    if( character.length != 1 )
        return;
    
    const uint16_t unicode = [character characterAtIndex:0];
    const auto modflags = _event.modifierFlags;
   
    const char *seq_resp = nullptr;
    switch( unicode ){
        case NSUpArrowFunctionKey:      seq_resp = "\eOA";      break;
        case NSDownArrowFunctionKey:    seq_resp = "\eOB";      break;
        case NSRightArrowFunctionKey:   seq_resp = "\eOC";      break;
        case NSLeftArrowFunctionKey:    seq_resp = "\eOD";      break;
        case NSF1FunctionKey:           seq_resp = "\eOP";      break;
        case NSF2FunctionKey:           seq_resp = "\eOQ";      break;
        case NSF3FunctionKey:           seq_resp = "\eOR";      break;
        case NSF4FunctionKey:           seq_resp = "\eOS";      break;
        case NSF5FunctionKey:           seq_resp = "\e[15~";    break;
        case NSF6FunctionKey:           seq_resp = "\e[17~";    break;
        case NSF7FunctionKey:           seq_resp = "\e[18~";    break;
        case NSF8FunctionKey:           seq_resp = "\e[19~";    break;
        case NSF9FunctionKey:           seq_resp = "\e[20~";    break;
        case NSF10FunctionKey:          seq_resp = "\e[21~";    break;
        case NSF11FunctionKey:          seq_resp = "\e[23~";    break;
        case NSF12FunctionKey:          seq_resp = "\e[24~";    break;
        case NSHomeFunctionKey:         seq_resp = "\eOH";      break;
        case NSInsertFunctionKey:       seq_resp = "\e[2~";     break;
        case NSDeleteFunctionKey:       seq_resp = "\e[3~";     break;
        case NSEndFunctionKey:          seq_resp = "\eOF";      break;
        case NSPageUpFunctionKey:       seq_resp = "\e[5~";     break;
        case NSPageDownFunctionKey:     seq_resp = "\e[6~";     break;
        case 9: /* tab */
            if (modflags & NSShiftKeyMask) /* do we really getting these messages? */
                seq_resp = "\e[Z";
            else
                seq_resp = "\011";
            break;
    }
    
    if( seq_resp ) {
        m_TaskInput(seq_resp, (int)strlen(seq_resp));
        return;
    }
    
    // process regular keys down
    if( modflags & NSControlKeyMask ) {
        unsigned short cc = 0xFFFF;
        if (unicode >= 'a' && unicode <= 'z')                           cc = unicode - 'a' + 1;
        else if (unicode == ' ' || unicode == '2' || unicode == '@')    cc = 0;
        else if (unicode == '[')                                        cc = 27;
        else if (unicode == '\\')                                       cc = 28;
        else if (unicode == ']')                                        cc = 29;
        else if (unicode == '^' || unicode == '6')                      cc = 30;
        else if (unicode == '-' || unicode == '_')                      cc = 31;
        m_TaskInput(&cc, 1);
        return;
    }

    if( modflags & NSAlternateKeyMask )
        character = (NSString*)CFBridgingRelease(CreateModifiedCharactersForKeyPress(_event.keyCode,
                                                                                     modflags) );
    else if( (modflags&NSDeviceIndependentModifierFlagsMask) == NSAlphaShiftKeyMask )
        character = _event.characters;
    
    const char* utf8 = character.UTF8String;
    m_TaskInput(utf8, (int)strlen(utf8));
}

void Parser::CSI_P()
{
    int p = m_Params[0];
    if(p > m_Scr.Width() - m_Scr.CursorX())
        p = m_Scr.Width() - m_Scr.CursorX();
    else if(!p)
        p = 1;
    m_Scr.DoShiftRowLeft(p);
}

void Parser::EscSave()
{
    m_State[0].x = m_Scr.CursorX();
    m_State[0].y = m_Scr.CursorY();
    memcpy(&m_State[1], &m_State[0], sizeof(m_State[0]));
}

void Parser::EscRestore()
{
    memcpy(&m_State[0], &m_State[1], sizeof(m_State[0]));
    m_Scr.GoTo(m_State[0].x, m_State[0].y);
    SetTranslate(m_State[0].charset_no == 0 ? m_State[0].g0_charset : m_State[0].g1_charset);
    UpdateAttrs();
}

void Parser::CSI_r()
{
//Esc[Line;Liner	Set top and bottom lines of a window	DECSTBM
//    int a  =10;
    if(m_Params[0] == 0)  m_Params[0]++;
    if(m_Params[1] == 0)  m_Params[1] = m_Scr.Height();

    // Minimum allowed region is 2 lines
    if(m_Params[0] < m_Params[1] && m_Params[1] <= m_Scr.Height())
    {
        m_Top       = m_Params[0] - 1;
        m_Bottom    = m_Params[1];
//        DoGoTo(0, 0);
    }
}

void Parser::CSI_L()
{
    int p = m_Params[0];
    if(p > m_Scr.Height() - m_Scr.CursorY())
        p = m_Scr.Height() - m_Scr.CursorY();
    else if(p == 0)
        p = 1;
    m_Scr.ScrollDown(m_Scr.CursorY(), m_Bottom, p);
}

void Parser::CSI_At()
{
    int p = m_Params[0];
    if(p > m_Scr.Width() - m_Scr.CursorX())
        p = m_Scr.Width() - m_Scr.CursorX();
    else if(p == 0)
        p = 1;
    m_Scr.DoShiftRowRight(p);
    m_Scr.EraseAt(m_Scr.CursorX(), m_Scr.CursorY(), p); // this seems to be redundant! CHECK!
}

void Parser::DoGoTo(int _x, int _y)
{
    if(!m_LineAbs)
    {
        _y += m_Top;
        
        if(_y < m_Top) _y = m_Top;
        else if(_y >= m_Bottom) _y = m_Bottom - 1;
    }
    
    m_Scr.GoTo(_x, _y);
}

void Parser::RI()
{
    if(m_Scr.CursorY() == m_Top)
        m_Scr.ScrollDown(m_Top, m_Bottom, 1);
    else
        m_Scr.DoCursorUp();
}

void Parser::LF()
{
    if(m_Scr.CursorY()+1 == m_Bottom)
        m_Scr.DoScrollUp(m_Top, m_Bottom, 1);
    else
        m_Scr.DoCursorDown();
}

void Parser::CR()
{
    m_Scr.GoTo(0, m_Scr.CursorY());
}

void Parser::HT()
{
    int x = m_Scr.CursorX();
    while(x < m_Scr.Width() - 1) {
        ++x;
        if(m_TabStop[x >> 5] & (1 << (x & 31)))
            break;
    }
    m_Scr.GoTo(x, m_Scr.CursorY());
}

void Parser::Resized()
{
    
    
//    int old_w = m_Width;
    int old_h = m_Height;
    
    m_Height = m_Scr.Height();
    m_Width = m_Scr.Width();

    if(m_Bottom == old_h)
        m_Bottom = m_Height;
    
    // any manipulations on cursor pos here?
    if(m_TaskScreenResizeCallback)
        m_TaskScreenResizeCallback(m_Width, m_Height);    
}

void Parser::CSI_T()
{
    int p = m_Params[0] ? m_Params[0] : 1;
    while(p--) m_Scr.ScrollDown(m_Top, m_Bottom, 1);
}

void Parser::CSI_S()
{
    int p = m_Params[0] ? m_Params[0] : 1;
    while(p--) m_Scr.DoScrollUp(m_Top, m_Bottom, 1);
}

void Parser::WriteTaskInput( const char *_buffer )
{
    m_TaskInput( _buffer, (int)strlen(_buffer) );
}

}
