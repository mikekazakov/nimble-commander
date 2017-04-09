#pragma once

@class MainWindowFilePanelState;
@class MainWndGoToButton;

@interface MainWindowFilePanelsStateToolbarDelegate : NSObject<NSToolbarDelegate>

- (instancetype) initWithFilePanelsState:(MainWindowFilePanelState*)_state;

@property (nonatomic, readonly) NSToolbar           *toolbar;

@property (nonatomic, readonly) MainWndGoToButton   *leftPanelGoToButton;
@property (nonatomic, readonly) NSProgressIndicator *leftPanelSpinningIndicator;

@property (nonatomic, readonly) MainWndGoToButton   *rightPanelGoToButton;
@property (nonatomic, readonly) NSProgressIndicator *rightPanelSpinningIndicator;

@end

