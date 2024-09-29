// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "StateActions.h"
#include "Actions/TabsManagement.h"
#include "Actions/ShowGoToPopup.h"
#include "Actions/ToggleSingleOrDualMode.h"
#include "Actions/ShowTabs.h"
#include "Actions/CopyFile.h"
#include "Actions/RevealInOppositePanel.h"
#include "Actions/ShowTerminal.h"
#include "Actions/SyncPanels.h"
#include "Actions/ExecuteExternalTool.h"
#include "Actions/ChangePanelsPosition.h"
#include "Actions/FocusOverlappedTerminal.h"
#include "Actions/FocusPanel.h"
#include "StateActionsDispatcher.h"

namespace nc::panel {

using namespace actions;

StateActionsMap BuildStateActionsMap(nc::config::Config &_global_config,
                                     nc::panel::NetworkConnectionsManager &_net_mgr,
                                     nc::utility::TemporaryFileStorage &_temp_file_storage,
                                     nc::utility::NativeFSManager &_native_fs_manager,
                                     const nc::panel::TagsStorage &_tags_storage)
{
    StateActionsMap m;
    auto add = [&](SEL _sel, actions::StateAction *_action) { m[_sel].reset(_action); };

    add(@selector(OnFileNewTab:), new AddNewTab);
    add(@selector(performClose:), new CloseTab);
    add(@selector(onFileCloseOtherTabs:), new CloseOtherTabs);
    add(@selector(OnFileCloseWindow:), new CloseWindow);
    add(@selector(onLeftPanelGoToButtonAction:), new ShowLeftGoToPopup{_net_mgr, _native_fs_manager, _tags_storage});
    add(@selector(onRightPanelGoToButtonAction:), new ShowRightGoToPopup{_net_mgr, _native_fs_manager, _tags_storage});
    add(@selector(onSwitchDualSinglePaneMode:), new ToggleSingleOrDualMode);
    add(@selector(OnWindowShowPreviousTab:), new ShowPreviousTab);
    add(@selector(OnWindowShowNextTab:), new ShowNextTab);
    add(@selector(OnShowTabs:), new ShowTabs);
    add(@selector(OnShowTerminal:), new ShowTerminal);
    add(@selector(OnSyncPanels:), new SyncPanels);
    add(@selector(OnSwapPanels:), new SwapPanels);
    add(@selector(OnFileCopyCommand:), new CopyTo{_global_config});
    add(@selector(OnFileCopyAsCommand:), new CopyAs{_global_config});
    add(@selector(OnFileRenameMoveCommand:), new MoveTo);
    add(@selector(OnFileRenameMoveAsCommand:), new MoveAs);
    add(@selector(OnFileOpenInOppositePanel:), new RevealInOppositePanel);
    add(@selector(OnFileOpenInNewOppositePanelTab:), new RevealInOppositePanelTab);
    add(@selector(onExecuteExternalTool:), new ExecuteExternalTool{_temp_file_storage});
    add(@selector(OnViewPanelsPositionMoveUp:), new MovePanelsUp);
    add(@selector(OnViewPanelsPositionMoveDown:), new MovePanelsDown);
    add(@selector(OnViewPanelsPositionShowHidePanels:), new ShowHidePanels);
    add(@selector(OnViewPanelsPositionFocusOverlappedTerminal:), new FocusOverlappedTerminal);
    add(@selector(onFocusLeftPanel:), new FocusLeftPanel);
    add(@selector(onFocusRightPanel:), new FocusRightPanel);
    return m;
}

} // namespace nc::panel
