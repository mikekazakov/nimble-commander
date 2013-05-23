//
//  ModernPanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 11.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelViewPresentation.h"

@class PanelView;

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
    
    static void UpdatePanelFrames(PanelView *_left, PanelView *_right, NSSize _size);
    
private:
    class IconCache;
    
    void OnDirectoryChanged() override;
    
    NSFont *m_Font;
    int m_LineHeight;
    
    bool m_IsLeft;
    
    NSSize m_Size;
    NSRect m_ItemsArea;
    int m_ItemsPerColumn;
    bool m_FirstDraw;
    
    CGGradientRef m_ActiveHeaderGradient;
    NSShadow *m_ActiveHeaderTextShadow;
    CGGradientRef m_InactiveHeaderGradient;
    NSShadow *m_InactiveHeaderTextShadow;
    
    IconCache *m_IconCache;
};
