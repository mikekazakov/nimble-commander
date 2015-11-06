//
//  ModernPanelViewPresenationItemsFooter.h
//  Files
//
//  Created by Michael G. Kazakov on 13.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "PanelViewTypes.h"
#include "PanelData.h"

class VFSListingItem;
struct PanelVolatileData;
struct PanelDataStatistics;
class ModernPanelViewPresentation;

class ModernPanelViewPresentationItemsFooter
{
public:
    ModernPanelViewPresentationItemsFooter(ModernPanelViewPresentation *_parent);
    
    void Draw(const VFSListingItem &_current_item,
              const PanelVolatileData &_current_item_vd,
              const PanelDataStatistics &_stats,
              PanelViewType _view_type,
              bool _active,
              bool _wnd_active,   // is window active now?              
              double _start_y,
              double _width
              );
    
    inline double Height() const { return m_Height; }    
    
private:
    NSString* FormHumanReadableBytesAndFiles(uint64_t _sz, int _total_files);
    void PrepareToDraw(const VFSListingItem& _current_item, const PanelVolatileData &_current_item_vd, const PanelDataStatistics &_stats, PanelViewType _view_type, bool _active);
    
    
    NSFont                          *m_Font = nil;
    double                          m_FontHeight = 0;
    double                          m_FontAscent = 0;
    double                          m_Height = 0;

    
    double                          m_DateTimeWidth = 50;
    double                          m_SizeWidth = 50;
    
    bool                            m_LastActive = false;
    PanelDataStatistics             m_LastStatistics;
    string                          m_LastItemName;
    string                          m_LastItemSymlink;
    uint64_t                        m_LastItemSize = 0;
    time_t                          m_LastItemDate = 0;
    bool                            m_LastItemIsDir = false;
    bool                            m_LastItemIsDotDot = false;
    
    
    NSAttributedString              *m_StatsStr;
    
    NSAttributedString              *m_ItemDateStr;
    NSAttributedString              *m_ItemSizeStr;
    NSAttributedString              *m_ItemNameStr;
    
    ModernPanelViewPresentation     *m_Parent;
};
