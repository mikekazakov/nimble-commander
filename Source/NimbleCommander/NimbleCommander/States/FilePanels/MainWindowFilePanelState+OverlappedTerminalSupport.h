// Copyright (C) 2015-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "MainWindowFilePanelState.h"

struct MainWindowFilePanelState_OverlappedTerminalSupport {
    FilePanelOverlappedTerminal *terminal = nil;
    int bottom_gap = 0;
    bool did_hide_panels_for_long_task = false;
};

@interface MainWindowFilePanelState (OverlappedTerminalSupport)

- (void)loadOverlappedTerminalSettingsAndRunIfNecessary;
- (void)saveOverlappedTerminalSettings;

- (bool)overlappedTerminalVisible;
- (void)activateOverlappedTerminal;
- (void)updateOverlappedTerminalVisibility;

- (bool)canIncreaseBootomTerminalGap;
- (void)increaseBottomTerminalGap;
- (bool)canDecreaseBottomTerminalGap;
- (void)decreaseBottomTerminalGap;

- (void)hidePanelsSplitView;
- (void)showPanelsSplitView;

- (void)synchronizeOverlappedTerminalWithPanel:(PanelController *)_pc;
- (void)handleCtrlAltTab;
- (void)feedOverlappedTerminalWithCurrentFilename;
- (void)feedOverlappedTerminalWithFilenamesMenu;

- (bool)executeInOverlappedTerminalIfPossible:(const std::string &)_filename at:(const std::string &)_path;

- (bool)isAnythingRunningInOverlappedTerminal;

- (int)bidForHandlingRoutedIntoOTKeyDown:(NSEvent *)_event;
- (void)handleRoutedIntoOTKeyDown:(NSEvent *)_event;

@end
