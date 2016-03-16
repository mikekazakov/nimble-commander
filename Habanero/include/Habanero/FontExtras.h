//
//  FontExtras.h
//  Files
//
//  Created by Michael G. Kazakov on 21.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <CoreText/CoreText.h>

class FontGeometryInfo
{
public:
    FontGeometryInfo();
    FontGeometryInfo(CTFontRef _font);
    
    inline double Size() const { return m_Size; }
    inline double Ascent() const { return m_Ascent; }
    inline double Descent() const { return m_Descent; }
    inline double Leading() const { return m_Leading; }
    inline double LineHeight() const { return m_LineHeight; }
    inline double MonospaceWidth() const { return m_MonospaceWidth; }
    
private:
    double m_Size;
    double m_Ascent;
    double m_Descent;
    double m_Leading;
    double m_LineHeight;
    double m_MonospaceWidth;
};
