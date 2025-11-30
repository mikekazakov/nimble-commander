// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.

#include <Cocoa/Cocoa.h>

@class PanelController;
@class MainWindowFilePanelState;

@interface NCPanelTabContextMenu : NSMenu <NSMenuItemValidation>

- (instancetype)initWithPanel:(PanelController *)_panel ofState:(MainWindowFilePanelState *)_state;

@end
