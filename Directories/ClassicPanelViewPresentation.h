//
//  ClassicPanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 06.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelViewPresentation.h"

@class PanelView;

class ClassicPanelViewPresentation : public PanelViewPresentation
{
public:
    ClassicPanelViewPresentation();
    
    virtual void Draw(NSRect _dirty_rect);
    virtual void OnFrameChanged(NSRect _frame);
    
    virtual NSRect GetItemColumnsRect();
    virtual int GetItemIndexByPointInView(CGPoint _point);
    
    virtual int GetNumberOfItemColumns();
    virtual int GetMaxItemsPerColumn();
    
    static void UpdatePanelFrames(PanelView *_left, PanelView *_right, NSSize _size);
    
private:
    void DrawWithShortMediumWideView(CGContextRef _context);
    void DrawWithFullView(CGContextRef _context);
    
    int m_SymbWidth;
    int m_SymbHeight;
    CTFontRef       m_FontCT;
    CGFontRef       m_FontCG;
};