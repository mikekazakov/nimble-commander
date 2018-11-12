// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <assert.h>
#include <math.h>
#include <stdexcept>
#include <Utility/FontExtras.h>

namespace nc::utility {

/**
 * Grabs geometry information from given font and returns it's line height.
 * Optionally returns font Ascent, Descent and Leading.
 */
static double GetLineHeightForFont(CTFontRef iFont, CGFloat *_ascent, CGFloat *_descent, CGFloat *_leading)
{
    assert(iFont != NULL);
    double ascent   = CTFontGetAscent(iFont);
    double descent  = CTFontGetDescent(iFont);
    double leading  = CTFontGetLeading(iFont);
    
    // calculation taken from here: http://stackoverflow.com/questions/5511830/how-does-line-spacing-work-in-core-text-and-why-is-it-different-from-nslayoutm
        
    if (leading < 0.)
        leading = 0.;
    else
        leading = floor(leading + 0.5);
    
    ascent  = floor(ascent  + 0.5);
    descent = floor(descent + 0.5);
    
    auto lineHeight = ascent + descent + leading;
    
    // in case if not sure that font line is calculating ok -
    // use the following block to compare, should be the same.
    /*
    NSFont *f = (__bridge NSFont*)iFont;
    NSLayoutManager *lm = [NSLayoutManager new];
    auto lm_lineheight = [lm defaultLineHeightForFont:f];
    */
    
    if(_ascent)  *_ascent = ascent;
    if(_descent) *_descent = descent;
    if(_leading) *_leading = leading;
    
    return lineHeight;
}

static double GetMonospaceFontCharWidth(CTFontRef _font)
{
    CFStringRef string = CFSTR("A");
    CFMutableAttributedStringRef attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    CFAttributedStringReplaceString(attrString, CFRangeMake(0, 0), string);
    CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFStringGetLength(string)), kCTFontAttributeName, _font);
    CTLineRef line = CTLineCreateWithAttributedString(attrString);
    double width = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
    CFRelease(line);
    CFRelease(attrString);
    return floor(width+0.5);
}

FontGeometryInfo::FontGeometryInfo()
{
    m_Size = 0.;
    m_Ascent = 0.;
    m_Descent = 0.;
    m_Leading = 0.;
    m_LineHeight = 0.;
    m_MonospaceWidth = 0.;
}

FontGeometryInfo::FontGeometryInfo(CTFontRef _font)
{
    if( !_font )
        throw std::invalid_argument("font can't be nullptr");
    
    m_LineHeight = GetLineHeightForFont(_font, &m_Ascent, &m_Descent, &m_Leading);
    m_MonospaceWidth = GetMonospaceFontCharWidth(_font);
    m_Size = CTFontGetSize(_font);
}

}
