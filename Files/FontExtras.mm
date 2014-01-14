//
//  FontExtras.cpp
//  Files
//
//  Created by Michael G. Kazakov on 21.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "FontExtras.h"

double GetLineHeightForFont(CTFontRef iFont, CGFloat *_ascent, CGFloat *_descent, CGFloat *_leading)
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

double GetMonospaceFontCharWidth(CTFontRef _font)
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