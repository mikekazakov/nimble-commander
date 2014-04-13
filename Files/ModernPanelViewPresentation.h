//
//  ModernPanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 11.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <memory>
#import "PanelViewPresentation.h"

using namespace std;

@class PanelView;
@class ObjcToCppObservingBridge;
class ModernPanelViewPresentationIconCache;
class IconsGenerator;
class ModernPanelViewPresentationHeader;
class ModernPanelViewPresentationItemsFooter;

class ModernPanelViewPresentation : public PanelViewPresentation
{
public:
    ModernPanelViewPresentation();
    ~ModernPanelViewPresentation() override;
    
    void Draw(NSRect _dirty_rect) override;
    void OnFrameChanged(NSRect _frame) override;
    
    NSRect GetItemColumnsRect() override;
    int GetItemIndexByPointInView(CGPoint _point) override;
    
    int GetNumberOfItemColumns() override;
    int GetMaxItemsPerColumn() override;
    
    
    double GetSingleItemHeight() override;
    
    
    
    static NSString* SizeToString6(const VFSListingItem &_dirent);
private:
    friend class ModernPanelViewPresentationIconCache;
    static void OnGeometryChanged(void *_obj, NSString *_key_path, id _objc_object, NSDictionary *_changed, void *_context);
    static void OnAppearanceChanged(void *_obj, NSString *_key_path, id _objc_object, NSDictionary *_changed, void *_context);
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
    
    ObjcToCppObservingBridge *m_GeometryObserver;
    ObjcToCppObservingBridge *m_AppearanceObserver;
    
    shared_ptr<IconsGenerator> m_IconCache;
    unique_ptr<ModernPanelViewPresentationHeader> m_Header;
    unique_ptr<ModernPanelViewPresentationItemsFooter> m_ItemsFooter;
};
