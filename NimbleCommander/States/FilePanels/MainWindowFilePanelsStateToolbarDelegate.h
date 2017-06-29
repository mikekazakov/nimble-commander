#pragma once

@class MainWindowFilePanelState;

@interface MainWindowFilePanelsStateToolbarDelegate : NSObject<NSToolbarDelegate>

- (instancetype) initWithFilePanelsState:(MainWindowFilePanelState*)_state;

@property (nonatomic, readonly) NSToolbar   *toolbar;
@property (nonatomic, readonly) NSButton    *leftPanelGoToButton;
@property (nonatomic, readonly) NSButton    *rightPanelGoToButton;

- (void) notifyStateWasAssigned;

@end

