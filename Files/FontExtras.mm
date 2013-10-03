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
    CGFloat lineHeight = 0.0/*, ascenderDelta = 0.0*/;
    
    assert(iFont != NULL);
    
    // Get the ascent from the font, already scaled for the font's size
    CGFloat ascent = CTFontGetAscent(iFont);
    if(_ascent) *_ascent = ascent;
    
    // Get the descent from the font, already scaled for the font's size
    CGFloat descent = CTFontGetDescent(iFont);
    if(_descent) *_descent = floor(descent + 0.5);
    
    // Get the leading from the font, already scaled for the font's size
    CGFloat leading = CTFontGetLeading(iFont);
    if(_leading) *_leading = leading;
    
    // calculation taken from here: http://stackoverflow.com/questions/5511830/how-does-line-spacing-work-in-core-text-and-why-is-it-different-from-nslayoutm
        
    if (leading < 0)
        leading = 0;
    
    leading = floor (leading + 0.5);
    lineHeight = floor (ascent + 0.5) + floor (descent + 0.5) + leading;
    
/*    if (leading > 0)
        ascenderDelta = 0;
    else
        ascenderDelta = floor (0.2 * lineHeight + 0.5);*/
    
//    defaultLineHeight = lineHeight + ascenderDelta;
//    return lineHeight + ascenderDelta;
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