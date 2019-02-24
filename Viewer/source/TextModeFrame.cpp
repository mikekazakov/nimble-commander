#include "TextModeFrame.h"
#include <Habanero/algo.h>

namespace nc::viewer {

TextModeFrame::TextModeFrame( const Source &_source ):
    m_WorkingSet{ _source.working_set  }
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
    
}
