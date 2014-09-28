//
//  PanelController+DelayedSelection.m
//  Files
//
//  Created by Michael G. Kazakov on 30.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController+DelayedSelection.h"
#import "MainWindowFilePanelState.h"
#import "Common.h"

@implementation PanelController (DelayedSelection)

///////////////////////////////////////////////////////////////////////////////////////////////
// Delayed cursors movement support

- (void) ScheduleDelayedSelectionChangeFor:(PanelControllerDelayedSelection)request checknow:(bool)_check_now;
{
    assert(dispatch_is_main_queue()); // to preserve against fancy threading stuff
    // we assume that _item_name will not contain any forward slashes
    
    m_DelayedSelection.isvalid = true;
    m_DelayedSelection.request_end = machtime() + request.timeout;
    m_DelayedSelection.filename = request.filename;
    m_DelayedSelection.done = [request.done copy];
    
    if(_check_now)
        [self CheckAgainstRequestedSelection];
}

- (bool) CheckAgainstRequestedSelection
{
    assert(dispatch_is_main_queue()); // to preserve against fancy threading stuff
    if(!m_DelayedSelection.isvalid)
        return false;
    
    if(machtime() > m_DelayedSelection.request_end)
    {
        m_DelayedSelection.isvalid = false;
        m_DelayedSelection.filename.clear();
        m_DelayedSelection.done = nil;
        return false;
    }
    
    // now try to find it
    int entryindex = m_Data.RawIndexForName(m_DelayedSelection.filename.c_str());
    if( entryindex >= 0 )
    {
        // we found this entry. regardless of appearance of this entry in current directory presentation
        // there's no reason to search for it again
        m_DelayedSelection.isvalid = false;
        void (^done)() = m_DelayedSelection.done;
        m_DelayedSelection.done = nil;
        
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
    m_DelayedSelection.isvalid = false;
    m_DelayedSelection.filename.clear();
    m_DelayedSelection.done = nil;
}



@end
