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
    CGFloat lineHeight = 0.0;
    
    assert(iFont != NULL);
    
    // Get the ascent from the font, already scaled for the font's size
    CGFloat ascent = CTFontGetAscent(iFont);
    lineHeight += ascent;
    if(_ascent) *_ascent = ascent;
    
    // Get the descent from the font, already scaled for the font's size
    CGFloat descent = CTFontGetDescent(iFont);
    lineHeight += descent;
    if(_descent) *_descent = descent;
    
    // Get the leading from the font, already scaled for the font's size
    CGFloat leading = CTFontGetLeading(iFont);
    lineHeight += leading;
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
    return width;
}