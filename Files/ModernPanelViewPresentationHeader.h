//
//  ModernPanelViewPresentationHeader.h
//  Files
//
//  Created by Michael G. Kazakov on 13.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "PanelData.h"

class ModernPanelViewPresentation;

class ModernPanelViewPresentationHeader
{
public:
    void SetFont(NSFont *_font);
    void Draw(const string& _path, // a path to draw
              bool _active,       // is panel active now?
              double _width,      // panel width
              PanelSortMode::Mode _sort_mode
            );
    
    inline double Height() const { return m_Height; }
private:
    void PrepareToDraw(const string& _path, bool _active, PanelSortMode::Mode _sort_mode);

    NSFont                          *m_Font = nil;
    double                          m_FontHeight = 0;
    double                          m_FontAscent = 0;
    double                          m_Height = 0;
    
    string                          m_LastHeaderPath;
    bool                            m_LastActive = false;
    PanelSortMode::Mode             m_LastSortMode = PanelSortMode::SortNoSort;
    
    NSAttributedString              *m_PathStr;
    NSAttributedString              *m_ModeStr;
};
