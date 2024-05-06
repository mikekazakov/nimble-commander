// Copyright (C) 2013-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreText/CoreText.h>
#include <vector>
#include <span>

#ifdef __OBJC__
#include <Cocoa/Cocoa.h>
#endif

namespace nc::utility {

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
    inline double PreciseMonospaceWidth() const noexcept { return m_PreciseMonospaceWidth; }

#ifdef __OBJC__
    // Returns a list of widths of each string in the container.
    // Widths will be rounded up to an integer.
    // Any line-breaking characters are substituded with ' ' - inputs are treated as single-line strings.
    static std::vector<unsigned short> CalculateStringsWidths(std::span<const CFStringRef> _strings, NSFont *_font);
#endif

private:
    double m_Size;
    double m_Ascent;
    double m_Descent;
    double m_Leading;
    double m_LineHeight;
    double m_MonospaceWidth;
    double m_PreciseMonospaceWidth;
};

} // namespace nc::utility

#ifdef __OBJC__

@interface NSFont (StringDescription)

+ (NSFont *)fontWithStringDescription:(NSString *)_description;
- (NSString *)toStringDescription;
- (std::string)toStdStringDescription;
- (bool)isSystemFont;

@end

#endif
