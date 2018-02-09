// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/MIMResponder.h>

@class MainWindowFilePanelState;

namespace nc::panel {
    namespace actions{
        class StateAction;
    }
    
    using StateActionsMap = unordered_map<SEL, unique_ptr<const actions::StateAction> >;
}

@interface NCPanelsStateActionsDispatcher : AttachedResponder
@property (nonatomic, readwrite) bool hasTerminal;

- (instancetype)initWithState:(MainWindowFilePanelState*)_state
                     andActionsMap:(const nc::panel::StateActionsMap&)_actions_map;

- (IBAction)OnSwapPanels:(id)sender;
- (IBAction)OnSyncPanels:(id)sender;
- (IBAction)OnShowTerminal:(id)sender;
- (IBAction)performClose:(id)sender;
- (IBAction)OnFileCloseWindow:(id)sender;
- (IBAction)OnFileNewTab:(id)sender;
- (IBAction)onSwitchDualSinglePaneMode:(id)sender;
- (IBAction)onLeftPanelGoToButtonAction:(id)sender;
- (IBAction)onRightPanelGoToButtonAction:(id)sender;
- (IBAction)OnWindowShowPreviousTab:(id)sender;
- (IBAction)OnWindowShowNextTab:(id)sender;
- (IBAction)OnShowTabs:(id)sender;
- (IBAction)OnFileCopyCommand:(id)sender;
- (IBAction)OnFileCopyAsCommand:(id)sender;
- (IBAction)OnFileRenameMoveCommand:(id)sender;
- (IBAction)OnFileRenameMoveAsCommand:(id)sender;
- (IBAction)OnFileOpenInOppositePanel:(id)sender;
- (IBAction)OnFileOpenInNewOppositePanelTab:(id)sender;
- (IBAction)onExecuteExternalTool:(id)sender;

@end
