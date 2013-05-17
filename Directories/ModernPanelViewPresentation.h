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
    virtual ~ModernPanelViewPresentation();
    
    virtual void Draw(NSRect _dirty_rect);
    virtual void OnFrameChanged(NSRect _frame);
    
    virtual NSRect GetItemColumnsRect();
    virtual int GetItemIndexByPointInView(CGPoint _point);
    
    virtual int GetNumberOfItemColumns();
    virtual int GetMaxItemsPerColumn();
    
    static void UpdatePanelFrames(PanelView *_left, PanelView *_right, NSSize _size);
    
private:
    void DrawView(CGContextRef _context);
    
    NSFont *m_Font;
    int m_LineHeight;
    
    bool m_IsLeft;
    // TODO: remove
    bool m_DrawIcons;
    
    NSSize m_Size;
    NSRect m_ItemsArea;
    int m_ItemsPerColumn;
    
    CGGradientRef m_ActiveHeaderGradient;
    NSShadow *m_ActiveHeaderTextShadow;
    CGGradientRef m_InactiveHeaderGradient;
    NSShadow *m_InactiveHeaderTextShadow;
};
