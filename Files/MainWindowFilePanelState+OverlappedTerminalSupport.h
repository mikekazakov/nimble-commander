//
//  MainWindowFilePanelState+OverlappedTerminalSupport.h
//  Files
//
//  Created by Michael G. Kazakov on 17/07/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "MainWindowFilePanelState.h"

struct MainWindowFilePanelState_OverlappedTerminalSupport
{
    FilePanelOverlappedTerminal *terminal = nil;
    int                          bottom_gap = 0;
    bool                         did_hide_panels_for_long_task = false;
};

@interface MainWindowFilePanelState (OverlappedTerminalSupport)

- (void) loadOverlappedTerminalSettingsAndRunIfNecessary;
- (void) saveOverlappedTerminalSettings;

- (bool) overlappedTerminalVisible;
- (void) activateOverlappedTerminal;
- (void) increaseBottomTerminalGap;
- (void) decreaseBottomTerminalGap;

- (void) hidePanelsSplitView;
- (void) showPanelsSplitView;

- (void) synchronizeOverlappedTerminalWithPanel:(PanelController*)_pc;
- (void) handleCtrlAltTab;
- (void) feedOverlappedTerminalWithCurrentFilename;
- (void) feedOverlappedTerminalWithFilenamesMenu;

/**
 * will handle it if:
 * 1) overlapped terminal is enabled and visible
 * 2) it is in Shell state
 * 3) Shell is not in Virgin state
 */
- (bool) handleReturnKeyWithOverlappedTerminal;

- (bool) executeInOverlappedTerminalIfPossible:(const string&)_filename at:(const string&)_path;

- (bool) isAnythingRunningInOverlappedTerminal;

- (bool) overlappedTerminalWillEatKeyDown:(NSEvent *)event;
- (bool) feedOverlappedTerminalWithKeyDown:(NSEvent *)event;

- (void) volumeWillUnmount:(NSNotification *)notification;

@end
