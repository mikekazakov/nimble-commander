//
//  PanelController+DelayedSelection.h
//  Files
//
//  Created by Michael G. Kazakov on 30.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"

@interface PanelController (DelayedSelection)

/** 
 * Delayed entry selection change - panel controller will memorize such request.
 * If _check_now flag is on then controller will look for requested element and if it was found - select it.
 * If there was another pending selection request - it will be overwrited by the new one.
 * Controller will check for entry appearance on every directory update.
 * Request will be removed upon directory change.
 * Once request is accomplished it will be removed.
 * If on any checking it will be found that time for request has went out - it will be removed (500ms is just ok for _time_out_in_ms).
 * Will also deselect any currenly selected items.
 */
- (void) ScheduleDelayedSelectionChangeFor:(NSString *)_item_name
                                 timeoutms:(int)_time_out_in_ms
                                  checknow:(bool)_check_now;

/**
 * Just the same as ScheduleDelayedSelectionChangeFor, but has plain-C _item_name parameter
 */
- (void) ScheduleDelayedSelectionChangeForC:(const char*)_item_name
                                  timeoutms:(int)_time_out_in_ms
                                   checknow:(bool)_check_now;

/**
 * Private PanelController method.
 * Return true if it moved or just set the cursor position.
 */
- (bool) CheckAgainstRequestedSelection;

/**
 * Private PanelController method.
 */
- (void) ClearSelectionRequest;

@end
