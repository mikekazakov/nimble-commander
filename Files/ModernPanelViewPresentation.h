//
//  ModernPanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 11.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelViewPresentation.h"
#import "ObjcToCppObservingBridge.h"

@class PanelView;
class ModernPanelViewPresentationIconCache;
class IconsGenerator;
class ModernPanelViewPresentationHeader;
class ModernPanelViewPresentationItemsFooter;
class ModernPanelViewPresentationVolumeFooter;

class ModernPanelViewPresentation : public PanelViewPresentation
{
public:
    ModernPanelViewPresentation();
    ~ModernPanelViewPresentation() override;
    
    void Draw(NSRect _dirty_rect) override;
    void OnFrameChanged(NSRect _frame) override;
    
    NSRect GetItemColumnsRect() override;
    int GetItemIndexByPointInView(CGPoint _point) override;
    
    int GetMaxItemsPerColumn() const override;
    
    
    double GetSingleItemHeight() override;
    
    NSRect ItemRect(int _item_index) const override;
    NSRect ItemFilenameRect(int _item_index) const override;
    void SetupFieldRenaming(NSScrollView *_editor, int _item_index) override;
    
    
    static NSString* SizeToString6(const VFSListingItem &_dirent);
private:
    void CalculateLayoutFromFrame();
    void OnDirectoryChanged() override;
    void BuildGeometry();
    void BuildAppearance();
    
    void DrawCursor(CGContextRef _context, NSRect _rc);
    
    NSFont *m_Font;
    double m_FontAscent;
    double m_FontHeight;
    double m_LineHeight; // full height of a row with gaps
    double m_SizeColumWidth;
    double m_DateColumnWidth;
    double m_TimeColumnWidth;
    
    bool m_IsLeft;
    
    NSSize m_Size;
    NSRect m_ItemsArea;
    int m_ItemsPerColumn;
    
    NSDictionary *m_ActiveSelectedItemTextAttr;
    NSDictionary *m_ItemTextAttr;
    NSDictionary *m_ActiveSelectedSizeColumnTextAttr;
    NSDictionary *m_SizeColumnTextAttr;
    NSDictionary *m_ActiveSelectedTimeColumnTextAttr;
    NSDictionary *m_TimeColumnTextAttr;
    
    NSColor     *m_RegularItemTextColor;
    NSColor     *m_ActiveSelectedItemTextColor;
    
    CGColorRef  m_BackgroundColor;
    CGColorRef  m_RegularOddBackgroundColor;
    CGColorRef  m_ActiveSelectedItemBackgroundColor;
    CGColorRef  m_InactiveSelectedItemBackgroundColor;
    CGColorRef  m_CursorFrameColor;
    CGColorRef  m_ColumnDividerColor;
    
    static NSImage *m_SymlinkArrowImage;
    
    ObjcToCppObservingBlockBridge *m_GeometryObserver;
    ObjcToCppObservingBlockBridge *m_AppearanceObserver;
    
    shared_ptr<IconsGenerator> m_IconCache;
    unique_ptr<ModernPanelViewPresentationHeader> m_Header;
    unique_ptr<ModernPanelViewPresentationItemsFooter> m_ItemsFooter;
    unique_ptr<ModernPanelViewPresentationVolumeFooter> m_VolumeFooter;
};
