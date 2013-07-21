//
//  PanelController.h
//  Directories
//
//  Created by Michael G. Kazakov on 22.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "PanelData.h"
#include "PanelView.h"

@class MainWindowController;

@interface PanelController : NSViewController

- (void) SetData:(PanelData*)_data;
- (void) SetView:(PanelView*)_view;
- (void) AttachToControls:(NSProgressIndicator*)_indicator eject:(NSButton*)_eject;
- (void) SetWindowController:(MainWindowController *)_cntrl;

- (void) LoadViewState:(NSDictionary *)_state;
- (NSDictionary *) SaveViewState;

- (void) RequestActivation;

- (void) HandleReturnButton;
- (void) HandleShiftReturnButton;


- (void) HandleFileView; // F3
- (void) ToggleSortingByName; // user pressed ctrl+F3 by default
- (void) ToggleSortingByExt; // user pressed ctrl+F4 by default
- (void) ToggleSortingByMTime; // user pressed ctrl+F5 by default
- (void) ToggleSortingBySize; // user pressed ctrl+F6 by default
- (void) ToggleSortingByBTime; // user pressed ctrl+F8 by default
- (void) ToggleViewHiddenFiles;
- (void) ToggleSeparateFoldersFromFiles;
- (void) ToggleCaseSensitiveComparison;
- (void) ToggleShortViewMode; // user pressed ctrl+1 by default
- (void) ToggleMediumViewMode; // user pressed ctrl+2 by default
- (void) ToggleFullViewMode; // user pressed ctrl+3 by default
- (void) ToggleWideViewMode; // user pressed ctrl+4 by default

- (PanelViewType) GetViewType;
- (PanelSortMode) GetUserSortMode;

- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long)_ticket;
- (void) RefreshDirectory; // user pressed cmd+r by default

- (void) GoToDirectory:(const char*) _dir;
- (bool) GoToDirectorySync:(const char*) _dir; // intended to use only in window initialization

- (void) ModifierFlagsChanged:(unsigned long)_flags; // to know if shift or something else is pressed
- (void)keyDown:(NSEvent *)event;

// delayed entry selection change
// panel controller will memorize such request
// if _check_now flag is on then controller will look for requested element and if it was found - select it
// if there was another pending selection request - it will be overwrited by the new one
// controller will check for entry appearance on every directory update
// request will be removed upon directory change
// one request is accomplished it will be removed
// if on any checking it will be found that time for request has went out - it will be removed
// 500ms is just ok for _time_out_in_ms
- (void) ScheduleDelayedSelectionChangeFor:(NSString *)_item_name timeoutms:(int)_time_out_in_ms checknow:(bool)_check_now;
- (void) ScheduleDelayedSelectionChangeForC:(const char*)_item_name timeoutms:(int)_time_out_in_ms checknow:(bool)_check_now;

- (void) SelectAllEntries: (bool) _select; // if false - then deselect all

@end
