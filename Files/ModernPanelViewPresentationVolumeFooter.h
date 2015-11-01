//
//  ModernPanelViewPresentationVolumeFooter.h
//  Files
//
//  Created by Michael G. Kazakov on 14.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "vfs/VFS.h"

class ModernPanelViewPresentationVolumeFooter
{
public:
    ModernPanelViewPresentationVolumeFooter();
    void Draw(const VFSStatFS &_stat, bool _wnd_active, double _start_y, double _width);
    inline double Height() const { return m_Height; }

private:
    void PrepareToDraw(const VFSStatFS &_stat);
    
    NSFont                          *m_Font = nil;
    NSAttributedString              *m_VolumeName;
    NSAttributedString              *m_FreeSpace;
    VFSStatFS                       m_CurrentStat;
    
    double                          m_FontHeight = 0;
    double                          m_FontAscent = 0;
    double                          m_Height = 0;
};
