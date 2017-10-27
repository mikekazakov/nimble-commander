// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
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

@end
