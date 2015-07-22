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
- (void) feedOverlappedTerminalWithCurrentFilename;

/**
 * will handle it if:
 * 1) overlapped terminal is enabled and visible
 * 2) it is in Shell state
 * 3) Shell is not in Virgin state
 */
- (bool) handleReturnKeyWithOverlappedTerminal;

- (bool) executeInOverlappedTerminalIfPossible:(const string&)_filename at:(const string&)_path;
@end
