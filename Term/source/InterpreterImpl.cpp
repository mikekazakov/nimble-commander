// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "InterpreterImpl.h"
#include <Habanero/CFString.h>
#include <Habanero/CFPtr.h>

namespace nc::term {

static std::u32string ConvertUTF8ToUTF32( std::string_view _utf8 );

InterpreterImpl::InterpreterImpl(Screen &_screen):
    m_Screen(_screen)
{
    m_Extent.height = m_Screen.Height();
    m_Extent.width = m_Screen.Width();
    m_Extent.top = 0;
    m_Extent.bottom = m_Screen.Height();
}

InterpreterImpl::~InterpreterImpl()
{
}

void InterpreterImpl::Interpret( Input _to_interpret )
{
    for( const auto &command: _to_interpret ) {
        using namespace input;
        const auto type = command.type;
        switch (type) {
            case Type::text:            
                ProcessText( *std::get_if<UTF8Text>(&command.payload) );
                break;
            case Type::line_feed:
                ProcessLF();
                break;
            case Type::carriage_return:
                ProcessCR();
                break;
            default:
                break;
        }
    }
}

void InterpreterImpl::SetOuput( Output _output )
{
    m_Output = std::move(_output);
}

void InterpreterImpl::ProcessText( const input::UTF8Text &_text )
{
    auto utf32 = ConvertUTF8ToUTF32( _text.characters );
    
    for( auto c: utf32 ) {
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

static std::u32string ConvertUTF8ToUTF32( std::string_view _utf8 )
{
    // temp and slow implementation
    auto str = base::CFPtr<CFStringRef>::adopt( CFStringCreateWithUTF8StringNoCopy( _utf8) ); 
    if( !str )
        return {};
    
    const auto utf8_len = CFStringGetLength(str.get());
    const auto utf32_len = CFStringGetBytes(str.get(),
                                            CFRangeMake(0, utf8_len),
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
                                            CFRangeMake(0, utf8_len),
                                            kCFStringEncodingUTF32LE,
                                            0,
                                            false,
                                            reinterpret_cast<UInt8*>(result.data()),
                                            result.size() * sizeof(char32_t),
                                            nullptr);
                                            
    assert( utf32_len == utf32_fact );

    return result; 
}


}
