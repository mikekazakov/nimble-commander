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
- (void) HandleReturnButton;
- (void) HandleShiftReturnButton;

- (void) ToggleSortingByName; // user pressed ctrl+F3 by default
- (void) ToggleSortingByExt; // user pressed ctrl+F4 by default
- (void) ToggleSortingByMTime; // user pressed ctrl+F5 by default
- (void) ToggleSortingBySize; // user pressed ctrl+F6 by default
- (void) ToggleSortingByBTime; // user pressed ctrl+F8 by default

- (void) FireDirectoryChanged: (const char*) _dir;
- (void) RefreshDirectory; // user pressed cmd+r by default

- (bool) GoToDirectory:(const char*) _dir;

@end
