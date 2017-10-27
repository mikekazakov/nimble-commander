// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class MainWindowFilePanelState;
@class NCOpsPoolViewController;

@interface MainWindowFilePanelsStateToolbarDelegate : NSObject<NSToolbarDelegate>

- (instancetype) initWithFilePanelsState:(MainWindowFilePanelState*)_state;

@property (nonatomic, readonly) NSToolbar   *toolbar;
@property (nonatomic, readonly) NSButton    *leftPanelGoToButton;
@property (nonatomic, readonly) NSButton    *rightPanelGoToButton;
@property (nonatomic, readonly) NCOpsPoolViewController *operationsPoolViewController;

- (void) notifyStateWasAssigned;

@end

