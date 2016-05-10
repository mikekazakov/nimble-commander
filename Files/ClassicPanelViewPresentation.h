//
//  ClassicPanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 06.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "vfs/VFS.h"
#include "PanelViewPresentation.h"
#include "OrthodoxMonospace.h"
#include "PanelViewPresentationItemsColoringFilter.h"
#include "Config.h"

class FontCache;
@class PanelView;

class ClassicPanelViewPresentation : public PanelViewPresentation
{
public:
    ClassicPanelViewPresentation(PanelView *_parent_view, PanelViewState *_view_state);
    
    void Draw(NSRect _dirty_rect) override;
    void OnFrameChanged(NSRect _frame) override;
    
    NSRect GetItemColumnsRect() override;
    int GetItemIndexByPointInView(CGPoint _point, PanelViewHitTest::Options _opt) override;
    
    int GetMaxItemsPerColumn() const override;
    
    int Granularity();
    
    double GetSingleItemHeight() override;
    NSRect ItemRect(int _item_index) const override;
    NSRect ItemFilenameRect(int _item_index) const override;
    
    void SetupFieldRenaming(NSScrollView *_editor, int _item_index) override;
    
private:
    void OnGeometryOptionsChanged();
    void BuildGeometry();
    void BuildAppearance();
    void DoDraw(CGContextRef _context);
    DoubleColor GetDirectoryEntryTextColor(const VFSListingItem &_dirent, const PanelData::PanelVolatileData& _vd, bool _is_focused);
    void CalcLayout(NSSize _from_px_size);
    oms::StringBuf<6> FormHumanReadableSizeRepresentation(unsigned long _sz) const;
    oms::StringBuf<6> FormHumanReadableSizeReprentationForDirEnt(const VFSListingItem &_dirent, const PanelData::PanelVolatileData& _vd) const;
    oms::StringBuf<256> FormHumanReadableBytesAndFiles(unsigned long _sz, int _total_files) const;
    
    array<int, 3>   ColumnWidthsShort() const;
    array<int, 2>   ColumnWidthsMedium() const;
    array<int, 4>   ColumnWidthsFull() const;
    array<int, 2>   ColumnWidthsWide() const;
    
    NSSize          m_FrameSize;
    int             m_SymbWidth = 0;
    int             m_SymbHeight = 0;
    int             m_BytesInDirectoryVPos = 0;
    int             m_EntryFooterVPos = 0;
    int             m_SelectionVPos = 0;
    
    vector<PanelViewPresentationItemsColoringRule> m_ColoringRules;
    
    shared_ptr<FontCache> m_FontCache;
    DoubleColor     m_BackgroundColor;
    DoubleColor     m_CursorBackgroundColor;
    DoubleColor     m_TextColor;
    DoubleColor     m_ActiveTextColor;
    DoubleColor     m_HighlightTextColor;
    bool            m_DrawVolumeInfo = true;
    vector<GenericConfig::ObservationTicket> m_ConfigObservations;
};
