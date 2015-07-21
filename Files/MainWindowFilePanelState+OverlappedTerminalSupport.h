//
//  MainWindowFilePanelState+OverlappedTerminalSupport.h
//  Files
//
//  Created by Michael G. Kazakov on 17/07/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState.h"

@interface MainWindowFilePanelState (OverlappedTerminalSupport)

- (bool) overlappedTerminalVisible;
- (void) activateOverlappedTerminal;
- (void) increaseBottomTerminalGap;
- (void) decreaseBottomTerminalGap;

- (void) hidePanelsSplitView;
- (void) showPanelsSplitView;

- (void) synchronizeOverlappedTerminalWithPanel:(PanelController*)_pc;
- (void) synchronizeOverlappedTerminalCWD:(const string&)_new_cwd;
- (void) handleCtrlAltTab;

@end
