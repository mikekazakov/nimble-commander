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
    ModernPanelViewPresentationHeader();
    void Draw(bool _active,       // is panel active now?
              bool _wnd_active,   // is window active now?
              double _width,      // panel width
              PanelData::PanelSortMode::Mode _sort_mode
            );
    void SetTitle(NSString *_title);
    
    inline double Height() const { return m_Height; }
private:
    NSFont                         *m_Font = nil;
    double                          m_FontHeight = 0;
    double                          m_FontAscent = 0;
    double                          m_Height = 0;
    
    PanelData::PanelSortMode::Mode  m_LastSortMode = PanelData::PanelSortMode::SortNoSort;

    NSAttributedString             *m_Title = nil;
    NSAttributedString             *m_ModeStr = nil;
};
