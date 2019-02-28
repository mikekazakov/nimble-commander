#include "TextModeFrame.h"
#include <Habanero/algo.h>
#include <cmath>

namespace nc::viewer {

TextModeFrame::TextModeFrame( const Source &_source ):
    m_WorkingSet{ _source.working_set  },
    m_FontInfo{ _source.font_info }
{
    assert( m_WorkingSet != nullptr );
    
    const auto monospace_width = _source.font_info.PreciseMonospaceWidth();
    const auto tab_width = _source.tab_spaces * monospace_width;
    
    auto attr_string = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    auto release_attr_string = at_scope_end([&]{ CFRelease(attr_string); });
    
    const auto pstyle = CreateParagraphStyleWithRegularTabs(tab_width);
    const auto release_pstyle = at_scope_end([&]{ CFRelease(pstyle); });
    
    const auto full_range = CFRangeMake(0, m_WorkingSet->Length());
    CFAttributedStringReplaceString(attr_string,
                                    CFRangeMake(0, 0),
                                    m_WorkingSet->String());
    CFAttributedStringSetAttribute(attr_string,
                                   full_range,
                                   kCTForegroundColorAttributeName,
                                   _source.foreground_color);
    CFAttributedStringSetAttribute(attr_string,
                                   full_range,
                                   kCTFontAttributeName,
                                   _source.font);
    CFAttributedStringSetAttribute(attr_string,
                                   full_range,
                                   kCTParagraphStyleAttributeName,
                                   pstyle);
    
    m_Lines = SplitAttributedStringsIntoLines(attr_string,
                                              _source.wrapping_width,
                                              monospace_width,
                                              tab_width,
                                              m_WorkingSet->CharactersByteOffsets());
}

TextModeFrame::TextModeFrame( TextModeFrame&& ) noexcept = default;
    
TextModeFrame::~TextModeFrame()
{
    m_Lines.clear(); // be sure to remove CTLines before removing the reference to the working set
}
    
TextModeFrame& TextModeFrame::operator=(TextModeFrame&&) noexcept = default;

int TextModeFrame::CharIndexForPosition( CGPoint _position ) const
{
    const auto line_index = (int)std::floor( _position.y / m_FontInfo.LineHeight() );
    if( line_index < 0 )
        return 0;
    if( line_index >= LinesNumber() )
        return m_WorkingSet->Length();
 
    const auto &line = Line(line_index);
    const auto char_index = (int)CTLineGetStringIndexForPosition(line.Line(),
                                                                 CGPointMake(_position.x, 0.));
    if( char_index < 0 )
        return 0;
    assert( char_index <= m_WorkingSet->Length() );
    
    // if the char index is after the last character in the string and that char is a newline
    // - move index one char back
    const auto is_hardbreak = [](char16_t c) -> bool {
        return c == 0xA || c == 0xD; // + more unicode stuff???
    };
    if( char_index == line.UniCharsEnd() &&
        line.UniCharInside(char_index - 1) &&
        is_hardbreak( m_WorkingSet->Characters()[char_index-1] ) ) {
        return char_index - 1;
    }
    
    return char_index;
}

int TextModeFrame::LineIndexForPosition( CGPoint _position ) const
{
    const auto line_index = (int)std::floor( _position.y / m_FontInfo.LineHeight() );
    if( line_index < 0 )
        return -1;
    if( line_index >= LinesNumber() )
        return LinesNumber();
    return line_index;
}

}
