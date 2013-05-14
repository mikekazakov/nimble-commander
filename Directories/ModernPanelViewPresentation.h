//
//  ModernPanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 11.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelViewPresentation.h"

class ModernPanelViewPresentation : public PanelViewPresentation
{
public:
    ModernPanelViewPresentation();
    
    virtual void Draw(NSRect _dirty_rect);
    virtual void OnFrameChanged(NSRect _frame);
    
    virtual NSRect GetItemColumnsRect();
    virtual int GetItemIndexByPointInView(CGPoint _point);
    
    virtual int GetNumberOfItemColumns();
    virtual int GetMaxItemsPerColumn();
    
private:
    void DrawShortView(CGContextRef _context);
    
    NSFont *m_Font;
    NSFont *m_HeaderFont;
    int m_LineHeight;
    int m_HeaderHeight;
    // TODO: Temporary hack! 
    bool m_IsLeft;
    // TODO: remove
    bool m_DrawIcons;
    CGSize m_Size;
};