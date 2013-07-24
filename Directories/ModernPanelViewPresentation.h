//
//  ModernPanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 11.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelViewPresentation.h"

@class PanelView;
class ModernPanelViewPresentationIconCache;

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
    
    void OnSkinSettingsChanged() override;
    
    static void UpdatePanelFrames(PanelView *_left, PanelView *_right, NSSize _size);
    
private:
    friend class ModernPanelViewPresentationIconCache;
    
    void OnDirectoryChanged() override;
    void BuildGeometry();
    void BuildAppearance();
    
    NSFont *m_Font;
    int m_FontHeight;
    int m_LineHeight; // full height of a row with gaps
    int m_SizeColumWidth;
    int m_DateColumnWidth;
    int m_TimeColumnWidth;
    int m_DateTimeFooterWidth;
    
    bool m_IsLeft;
    
    NSSize m_Size;
    NSRect m_ItemsArea;
    int m_ItemsPerColumn;
    
    NSDictionary *m_ActiveSelectedItemTextAttr;
    NSDictionary *m_ItemTextAttr;
    NSDictionary *m_ActiveSelectedSizeColumnTextAttr;
    NSDictionary *m_SizeColumnTextAttr;
    NSDictionary *m_ActiveSelectedItemsFooterTextAttr;
    NSDictionary *m_SelectedItemsFooterTextAttr;    
    
    CGGradientRef m_ActiveHeaderGradient;
    NSShadow *m_ActiveHeaderTextShadow;
    CGGradientRef m_InactiveHeaderGradient;
    NSShadow *m_InactiveHeaderTextShadow;
    
    ModernPanelViewPresentationIconCache *m_IconCache;
};
