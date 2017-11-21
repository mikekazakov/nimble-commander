// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.

@class PanelController;
@class MainWindowFilePanelState;

@interface NCPanelTabContextMenu : NSMenu

- (instancetype) initWithPanel:(PanelController*)_panel
                       ofState:(MainWindowFilePanelState*)_state;

@end
