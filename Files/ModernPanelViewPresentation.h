//
//  ModernPanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 11.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/FontExtras.h>
#include "PanelViewPresentation.h"
#include "PanelViewPresentationItemsColoringFilter.h"
#include "ObjcToCppObservingBridge.h"
#include "IconsGenerator.h"
#include "Config.h"

@class PanelView;
class ModernPanelViewPresentationIconCache;
class ModernPanelViewPresentationHeader;
class ModernPanelViewPresentationItemsFooter;
class ModernPanelViewPresentationVolumeFooter;


class ModernPanelViewPresentation : public PanelViewPresentation
{
public:
    ModernPanelViewPresentation(PanelView *_parent_view, PanelViewState *_view_state);
    ~ModernPanelViewPresentation() override;
    
    void Draw(NSRect _dirty_rect) override;
    void OnFrameChanged(NSRect _frame) override;
    
    NSRect GetItemColumnsRect() override;
    int GetItemIndexByPointInView(CGPoint _point, PanelViewHitTest::Options _opt) override;
    
    int GetMaxItemsPerColumn() const override;
    
    
    double GetSingleItemHeight() override;
    
    NSRect ItemRect(int _item_index) const override;
    NSRect ItemFilenameRect(int _item_index) const override;
    void SetupFieldRenaming(NSScrollView *_editor, int _item_index) override;
    
    NSString* FileSizeToString(const VFSListingItem &_dirent, const PanelVolatileData &_vd) const;
private:
    struct ColoringAttrs {
        NSDictionary *focused;
        NSDictionary *regular;
        NSDictionary *focused_size;
        NSDictionary *regular_size;
        NSDictionary *focused_time;
        NSDictionary *regular_time;
    };
    
    struct ItemLayout {
        NSRect whole_area       = { {0, 0}, {-1, -1}};
        NSRect filename_area    = { {0, 0}, {-1, -1}};
        NSRect filename_fact    = { {0, 0}, {-1, -1}};
        NSRect icon             = { {0, 0}, {-1, -1}};
        // time?
        // size?
        // date?
        // mb later
    };
    
    NSPoint ItemOrigin(int _item_index) const; // for not visible items return {0,0}
    ItemLayout LayoutItem(int _item_index) const;
    void CalculateLayoutFromFrame();
    void OnDirectoryChanged() override;
    void OnGeometryOptionsChanged();
    void BuildGeometry();
    void BuildAppearance();
    const ColoringAttrs& AttrsForItem(const VFSListingItem& _item, const PanelVolatileData& _item_vd) const;
    
    NSFont *m_Font;
    FontGeometryInfo m_FontInfo;
    double m_LineHeight; // full height of a row with gaps
    
    double m_LineTextBaseline;
    double m_SizeColumWidth;
    double m_DateColumnWidth;
    double m_TimeColumnWidth;
    
    bool m_IsLeft;
    
    NSSize m_Size;
    NSRect m_ItemsArea;
    int m_ItemsPerColumn;
    
    NSColor* m_RegularBackground;
    NSColor* m_OddBackground;
    NSColor* m_ActiveCursor;
    NSColor* m_InactiveCursor;
    CGColorRef  m_ColumnDividerColor;
    vector<PanelViewPresentationItemsColoringRule> m_ColoringRules;
    vector<ColoringAttrs> m_ColoringAttrs;
    
    static NSImage *m_SymlinkArrowImage;
    
    ObjcToCppObservingBlockBridge *m_TitleObserver;
    
    IconsGenerator m_IconCache;
    unique_ptr<ModernPanelViewPresentationHeader> m_Header;
    unique_ptr<ModernPanelViewPresentationItemsFooter> m_ItemsFooter;
    unique_ptr<ModernPanelViewPresentationVolumeFooter> m_VolumeFooter;
    vector<GenericConfig::ObservationTicket>    m_ConfigObservations;
};
