//
//  ClassicPanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 06.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelViewPresentation.h"
#import "OrthodoxMonospace.h"
#import "ObjcToCppObservingBridge.h"
#import "VFS.h"
#import "PanelViewPresentationItemsColoringFilter.h"

class FontCache;
@class PanelView;

struct ClassicPanelViewPresentationItemsColoringFilter
{
    string                                      name;
    DoubleColor                                 unfocused;
    DoubleColor                                 focused;
    PanelViewPresentationItemsColoringFilter    filter;
    NSDictionary *Archive() const;
    static ClassicPanelViewPresentationItemsColoringFilter Unarchive(NSDictionary *_dict);
};

class ClassicPanelViewPresentation : public PanelViewPresentation
{
public:
    ClassicPanelViewPresentation();
    
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
    void SetQuickSearchPrompt(NSString *_text) override;
    
private:
    void BuildGeometry();
    void BuildAppearance();
    void DoDraw(CGContextRef _context);
    const DoubleColor& GetDirectoryEntryTextColor(const VFSListingItem &_dirent, bool _is_focused);
    void CalcLayout(NSSize _from_px_size);
    
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
    
    vector<ClassicPanelViewPresentationItemsColoringFilter> m_ColoringRules;
    
    shared_ptr<FontCache> m_FontCache;
    DoubleColor     m_BackgroundColor;
    DoubleColor     m_CursorBackgroundColor;
    DoubleColor     m_TextColor;
    DoubleColor     m_ActiveTextColor;
    DoubleColor     m_HighlightTextColor;
    ObjcToCppObservingBlockBridge *m_GeometryObserver;
    ObjcToCppObservingBlockBridge *m_AppearanceObserver;
    bool            m_DrawVolumeInfo = true;
    string          m_QuickSearchPrompt;
};
