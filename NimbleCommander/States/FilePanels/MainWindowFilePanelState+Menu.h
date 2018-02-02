// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "MainWindowFilePanelState.h"

@interface MainWindowFilePanelState (Menu)

- (IBAction)onExternMenuActionCalled:(id)sender;
- (IBAction)onLeftPanelGoToButtonAction:(id)sender;
- (IBAction)onRightPanelGoToButtonAction:(id)sender;

@end
