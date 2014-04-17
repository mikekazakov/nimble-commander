//
//  PanelViewPresentation.h
//  Files
//
//  Created by Pavel Dogurevich on 06.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelViewTypes.h"
#import "VFS.h"
#import "DispatchQueue.h"

@class PanelView;

class PanelViewPresentation
{
public:
    virtual ~PanelViewPresentation();
    
    void SetState(PanelViewState *_state);
    void SetView(PanelView *_view);
    
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
    
    /**
     * Return a height of a single file item. So this height*number_of_items_vertically should be something like height of a view minus decors.
     */
    virtual double GetSingleItemHeight() = 0;
    
protected:
    void SetViewNeedsDisplay();
    
    inline const VFSStatFS &StatFS() const { return m_StatFS; }
    void UpdateStatFS();
    
    PanelViewState *m_State = nullptr;
    
    inline PanelView *View() { return m_View; }
private:
    virtual void OnDirectoryChanged() {}

    VFSStatFS                      m_StatFS;
    uint64_t                       m_StatFSLastUpdate = 0;
    SerialQueue                    m_StatFSQueue = SerialQueueT::Make();
    VFSHost                       *m_StatFSLastHost = nullptr;
    string                         m_StatFSLastPath;
    
    __unsafe_unretained PanelView *m_View = nil;
};
