// Copyright (C) 2018-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/MIMResponder.h>
#include <memory>
#include <ankerl/unordered_dense.h>

@class MainWindowFilePanelState;

namespace nc::utility {
class ActionsShortcutsManager;
}

namespace nc::panel {
namespace actions {
struct StateAction;
}

using StateActionsMap = ankerl::unordered_dense::map<SEL, std::unique_ptr<const actions::StateAction>>;
} // namespace nc::panel

@interface NCPanelsStateActionsDispatcher : AttachedResponder
@property(nonatomic, readwrite) bool hasTerminal;

- (instancetype)initWithState:(MainWindowFilePanelState *)_state
                    actionsMap:(const nc::panel::StateActionsMap &)_actions_map
    andActionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_action_shortcuts_manager;

- (IBAction)OnSwapPanels:(id)sender;
- (IBAction)OnSyncPanels:(id)sender;
- (IBAction)onFocusLeftPanel:(id)sender;
- (IBAction)onFocusRightPanel:(id)sender;
- (IBAction)OnShowTerminal:(id)sender;
- (IBAction)performClose:(id)sender;
- (IBAction)OnFileCloseWindow:(id)sender;
- (IBAction)onFileCloseOtherTabs:(id)sender;
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
- (IBAction)OnViewPanelsPositionMoveUp:(id)sender;
- (IBAction)OnViewPanelsPositionMoveDown:(id)sender;
- (IBAction)OnViewPanelsPositionShowHidePanels:(id)sender;
- (IBAction)OnViewPanelsPositionFocusOverlappedTerminal:(id)sender;

@end
