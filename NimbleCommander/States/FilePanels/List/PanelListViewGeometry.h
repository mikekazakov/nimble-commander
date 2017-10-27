// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

class PanelListViewGeometry
{
public:
    PanelListViewGeometry();
    PanelListViewGeometry( NSFont* _font, int _icon_scale);

    short   LineHeight()    const { return m_LineHeight; }
    short   TextBaseLine()  const { return m_TextBaseLine; }
    short   IconSize()      const { return m_IconSize; }
    short   LeftInset()     const { return 7;  }
    short   TopInset()      const { return 1;  }
    short   RightInset()    const { return 5;  }
    short   BottomInset()   const { return 1;  }
    
private:
    short   m_LineHeight;
    short   m_TextBaseLine;
    short   m_IconSize;
};
