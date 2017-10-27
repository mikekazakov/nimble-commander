// Copyright (C) 2013-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreText/CoreText.h>
#include <vector>

#ifdef __OBJC__
    #include <Cocoa/Cocoa.h>
#endif



class FontGeometryInfo
{
public:
    FontGeometryInfo();
    FontGeometryInfo(CTFontRef _font);
#ifdef __OBJC__
    FontGeometryInfo(NSFont *_font);
#endif
    
    inline double Size() const noexcept { return m_Size; }
    inline double Ascent() const noexcept { return m_Ascent; }
    inline double Descent() const noexcept { return m_Descent; }
    inline double Leading() const noexcept { return m_Leading; }
    inline double LineHeight() const noexcept { return m_LineHeight; }
    inline double MonospaceWidth() const noexcept { return m_MonospaceWidth; }
    
#ifdef __OBJC__
    static std::vector<short> CalculateStringsWidths( const std::vector<CFStringRef> &_strings, NSFont *_font );
#endif
    
private:
    double m_Size;
    double m_Ascent;
    double m_Descent;
    double m_Leading;
    double m_LineHeight;
    double m_MonospaceWidth;
};

#ifdef __OBJC__

@interface NSFont (StringDescription)

+ (NSFont*) fontWithStringDescription:(NSString*)_description;
- (NSString*) toStringDescription;

@end

#endif
