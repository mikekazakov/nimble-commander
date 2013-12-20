//
//  PanelController+DelayedSelection.m
//  Files
//
//  Created by Michael G. Kazakov on 30.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController+DelayedSelection.h"
#import "Common.h"

@implementation PanelController (DelayedSelection)

///////////////////////////////////////////////////////////////////////////////////////////////
// Delayed cursors movement support

- (void) ScheduleDelayedSelectionChangeFor:(NSString *)_item_name timeoutms:(int)_time_out_in_ms checknow:(bool)_check_now
{
    [self ScheduleDelayedSelectionChangeForC:[_item_name fileSystemRepresentation]
                                   timeoutms:_time_out_in_ms
                                    checknow:_check_now];
}

- (void) ScheduleDelayedSelectionChangeForC:(const char*)_item_name timeoutms:(int)_time_out_in_ms checknow:(bool)_check_now
{
    assert(dispatch_is_main_queue()); // to preserve against fancy threading stuff
    assert(_item_name);
    // we assume that _item_name will not contain any forward slashes
    
    m_DelayedSelection.isvalid = true;
    m_DelayedSelection.request_end = GetTimeInNanoseconds() + _time_out_in_ms*USEC_PER_SEC;
    strcpy(m_DelayedSelection.filename, _item_name);
    
    if(_check_now)
        [self CheckAgainstRequestedSelection];
}

- (bool) CheckAgainstRequestedSelection
{
    assert(dispatch_is_main_queue()); // to preserve against fancy threading stuff
    if(!m_DelayedSelection.isvalid)
        return false;
    
    uint64_t now = GetTimeInNanoseconds();
    if(now > m_DelayedSelection.request_end)
    {
        m_DelayedSelection.isvalid = false;
        return false;
    }
    
    // now try to find it
    int entryindex = m_Data->RawIndexForName(m_DelayedSelection.filename);
    if( entryindex >= 0 )
    {
        // we found this entry. regardless of appearance of this entry in current directory presentation
        // there's no reason to search for it again
        m_DelayedSelection.isvalid = false;
        
        int sortpos = m_Data->SortedIndexForRawIndex(entryindex);
        if( sortpos >= 0 )
        {
            [m_View SetCursorPosition:sortpos];
            m_Data->CustomFlagsSelectAll(false);
            if(![self IsActivePanel])
               [self RequestActivation];
            return true;
        }
    }
    return false;
}

- (void) ClearSelectionRequest
{
    m_DelayedSelection.isvalid = false;
}



@end
