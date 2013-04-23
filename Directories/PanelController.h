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

@interface PanelController : NSViewController

- (void) SetData:(PanelData*)_data;
- (void) SetView:(PanelView*)_view;
- (void) AttachToIndicator:(NSProgressIndicator*)_ind;

- (void) LoadViewState:(NSDictionary *)_state;
- (NSDictionary *) SaveViewState;

- (void) HandleReturnButton;
- (void) HandleShiftReturnButton;

- (void) ToggleSortingByName; // user pressed ctrl+F3 by default
- (void) ToggleSortingByExt; // user pressed ctrl+F4 by default
- (void) ToggleSortingByMTime; // user pressed ctrl+F5 by default
- (void) ToggleSortingBySize; // user pressed ctrl+F6 by default
- (void) ToggleSortingByBTime; // user pressed ctrl+F8 by default
- (void) ToggleViewHiddenFiles;
- (void) ToggleSeparateFoldersFromFiles;
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

// background directory size calculation support
- (void) DidCalculatedDirectorySizeForEntry:(const char*) _dir size:(unsigned long)_size;

@end
