// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ShowQuickLook.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../MainWindowFilePanelState.h"
#include "../Views/FilePanelMainSplitView.h"
#include "../PanelAux.h"

namespace nc::panel::actions {

bool ShowQuickLook::Predicate(PanelController *_target) const
{
    return _target.view.item;
}

void ShowQuickLook::Perform(PanelController *_target, [[maybe_unused]] id _sender) const
{
    const auto state = _target.state;

    if( !ShowQuickLookAsFloatingPanel() ) {
        if( state.anyPanelCollapsed ) {
            if( [state isLeftController:_target] )
                [state.splitView expandRightView];
            else if( [state isRightController:_target] )
                [state.splitView expandLeftView];
        }
    }

    if( [state quickLookForPanel:_target make:false] ) {
        [state closeAttachedUI:_target];
    }
    else {
        if( [state quickLookForPanel:_target make:true] )
            [_target updateAttachedQuickLook];
    }
}

} // namespace nc::panel::actions
