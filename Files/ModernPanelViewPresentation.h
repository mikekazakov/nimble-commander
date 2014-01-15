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
    
private:
    friend class ModernPanelViewPresentationIconCache;
    static void OnGeometryChanged(void *_obj, NSString *_key_path, id _objc_object, NSDictionary *_changed, void *_context);
    static void OnAppearanceChanged(void *_obj, NSString *_key_path, id _objc_object, NSDictionary *_changed, void *_context);
    void CalculateLayoutFromFrame();
    
    void OnDirectoryChanged() override;
    void BuildGeometry();
    void BuildAppearance();
    
    NSFont *m_Font;
    double m_FontAscent;
    double m_FontHeight;
    double m_LineHeight; // full height of a row with gaps
    double m_SizeColumWidth;
    double m_DateColumnWidth;
    double m_TimeColumnWidth;
    double m_DateTimeFooterWidth;
    
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
    
    NSDictionary *m_ActiveSelectedItemsFooterTextAttr;
    NSDictionary *m_SelectedItemsFooterTextAttr;    
    
    NSColor     *m_RegularItemTextColor;
    NSColor     *m_ActiveSelectedItemTextColor;
    
    CGColorRef  m_BackgroundColor;
    CGColorRef  m_RegularOddBackgroundColor;
    CGColorRef  m_ActiveSelectedItemBackgroundColor;
    CGColorRef  m_InactiveSelectedItemBackgroundColor;
    CGColorRef  m_CursorFrameColor;
    CGColorRef  m_ColumnDividerColor;
    
    CGGradientRef m_ActiveHeaderGradient;
    NSShadow *m_ActiveHeaderTextShadow;
    CGGradientRef m_InactiveHeaderGradient;
    NSShadow *m_InactiveHeaderTextShadow;

    NSImage *m_SymlinkArrowImage;
    
    ObjcToCppObservingBridge *m_GeometryObserver;
    ObjcToCppObservingBridge *m_AppearanceObserver;
    
    shared_ptr<IconsGenerator> m_IconCache;
};
