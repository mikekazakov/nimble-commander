//
//  PanelController+DelayedSelection.m
//  Files
//
//  Created by Michael G. Kazakov on 30.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "MainWindowFilePanelState.h"
#include "PanelController+DelayedSelection.h"

@implementation PanelController (DelayedSelection)

///////////////////////////////////////////////////////////////////////////////////////////////
// Delayed cursors movement support

- (void) ScheduleDelayedSelectionChangeFor:(PanelControllerDelayedSelection)request;
{
    assert(dispatch_is_main_queue()); // to preserve against fancy threading stuff
    // we assume that _item_name will not contain any forward slashes
    
    if(request.filename.empty())
        return;
    
    m_DelayedSelection.request_end = machtime() + request.timeout;
    m_DelayedSelection.filename = request.filename;
    m_DelayedSelection.done = request.done;
    
    if(request.check_now)
        [self CheckAgainstRequestedSelection];
}

- (bool) CheckAgainstRequestedSelection
{
    assert(dispatch_is_main_queue()); // to preserve against fancy threading stuff
    if(m_DelayedSelection.filename.empty())
        return false;
    
    if(machtime() > m_DelayedSelection.request_end) {
        m_DelayedSelection.filename.clear();
        m_DelayedSelection.done = nullptr;
        return false;
    }
    
    // now try to find it
    int entryindex = m_Data.RawIndexForName(m_DelayedSelection.filename.c_str());
    if( entryindex >= 0 )
    {
        // we found this entry. regardless of appearance of this entry in current directory presentation
        // there's no reason to search for it again
        auto done = m_DelayedSelection.done;
        m_DelayedSelection.done = nullptr;
        
        int sortpos = m_Data.SortedIndexForRawIndex(entryindex);
        if( sortpos >= 0 )
        {
            m_View.curpos = sortpos;
            m_Data.CustomFlagsSelectAllSorted(false);
            if(!self.isActive)
                [(MainWindowFilePanelState*)self.state ActivatePanelByController:self];
            if(done)
                done();
            return true;
        }
    }
    return false;
}

- (void) ClearSelectionRequest
{
    m_DelayedSelection.filename.clear();
    m_DelayedSelection.done = nullptr;
}



@end
