//
//  PanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 06.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelViewTypes.h"

@class PanelView;

class PanelViewPresentation
{
public:    
    PanelViewPresentation();
    virtual ~PanelViewPresentation() {}
    
    void SetState(PanelViewState *_state);
    void SetView(PanelView *_view);
    
//    void DirectoryChanged(PanelViewDirectoryChangeType _type, int _cursor);
    
    void SetCursorPos(int _pos);
    void ScrollCursor(int _idx, int _idy);
    void MoveCursorToNextItem();
    void MoveCursorToPrevItem();
    void MoveCursorToNextPage();
    void MoveCursorToPrevPage();
    void MoveCursorToNextColumn();
    void MoveCursorToPrevColumn();
    void MoveCursorToFirstItem();
    void MoveCursorToLastItem();
    
    void EnsureCursorIsVisible();
    
    virtual void Draw(NSRect _dirty_rect) = 0;
    virtual void OnFrameChanged(NSRect _frame) = 0;
    
    virtual NSRect GetItemColumnsRect() = 0;
    
    // Calculates cursor postion which corresponds to the point in view.
    // Returns -1 if point is out of the files' view area.
    virtual int GetItemIndexByPointInView(CGPoint _point) = 0;
    
    virtual int GetNumberOfItemColumns() = 0;
    virtual int GetMaxItemsPerColumn() = 0;
    int GetMaxVisibleItems();
    
protected:
    void SetViewNeedsDisplay();
    
    PanelViewState *m_State;
    
private:
    virtual void OnDirectoryChanged() {}
    
    __unsafe_unretained PanelView *m_View;
};
