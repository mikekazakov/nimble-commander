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
    
    void Draw(NSRect _dirty_rect) override;
    void OnFrameChanged(NSRect _frame) override;
    
    NSRect GetItemColumnsRect() override;
    int GetItemIndexByPointInView(CGPoint _point) override;
    
    int GetNumberOfItemColumns() override;
    int GetMaxItemsPerColumn() override;
    
    static void UpdatePanelFrames(PanelView *_left, PanelView *_right, NSSize _size);
    
private:
    void DrawWithShortMediumWideView(CGContextRef _context);
    void DrawWithFullView(CGContextRef _context);
    
    
    
    int m_SymbWidth;
    int m_SymbHeight;
    CTFontRef       m_FontCT;
    CGFontRef       m_FontCG;
};