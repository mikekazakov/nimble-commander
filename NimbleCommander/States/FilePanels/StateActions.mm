// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
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
#include "StateActionsDispatcher.h"

namespace nc::panel {

using namespace actions;
    
StateActionsMap BuildStateActionsMap
    (NetworkConnectionsManager &_net_mgr,
     nc::utility::TemporaryFileStorage &_temp_file_storage)
{
    StateActionsMap m;
    auto add = [&](SEL _sel, actions::StateAction *_action) {
        m[_sel].reset( _action );
    };
    
    add(@selector(OnFileNewTab:), new AddNewTab);
    add(@selector(performClose:), new CloseTab);
    add(@selector(onFileCloseOtherTabs:), new CloseOtherTabs);    
    add(@selector(OnFileCloseWindow:), new CloseWindow);
    add(@selector(onLeftPanelGoToButtonAction:),
        new ShowLeftGoToPopup{_net_mgr, @selector(onRightPanelGoToButtonAction:)});
    add(@selector(onRightPanelGoToButtonAction:),
        new ShowRightGoToPopup{_net_mgr, @selector(onLeftPanelGoToButtonAction:)});
    add(@selector(onSwitchDualSinglePaneMode:), new ToggleSingleOrDualMode);
    add(@selector(OnWindowShowPreviousTab:), new ShowPreviousTab);
    add(@selector(OnWindowShowNextTab:), new ShowNextTab);
    add(@selector(OnShowTabs:), new ShowTabs);
    add(@selector(OnShowTerminal:), new ShowTerminal);
    add(@selector(OnSyncPanels:), new SyncPanels);
    add(@selector(OnSwapPanels:), new SwapPanels);
    add(@selector(OnFileCopyCommand:), new CopyTo);
    add(@selector(OnFileCopyAsCommand:), new CopyAs);
    add(@selector(OnFileRenameMoveCommand:), new MoveTo);
    add(@selector(OnFileRenameMoveAsCommand:), new MoveAs);
    add(@selector(OnFileOpenInOppositePanel:), new RevealInOppositePanel);
    add(@selector(OnFileOpenInNewOppositePanelTab:), new RevealInOppositePanelTab);
    add(@selector(onExecuteExternalTool:), new ExecuteExternalTool{_temp_file_storage});
    
    return m;
}
    
}
