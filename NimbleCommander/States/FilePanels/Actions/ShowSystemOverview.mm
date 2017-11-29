// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ShowSystemOverview.h"
#include "../PanelController.h"
#include "../MainWindowFilePanelState.h"

namespace nc::panel::actions {

bool ShowSystemOverview::Predicate( PanelController *_target ) const
{
    return !_target.state.anyPanelCollapsed;
}

void ShowSystemOverview::Perform( PanelController *_target, id _sender ) const
{
    const auto state = _target.state;
        
    if( [state briefSystemOverviewForPanel:_target make:false] ) {
        [state closeAttachedUI:_target];
    }
    else {
        if( [state briefSystemOverviewForPanel:_target make:true] )
            [_target updateAttachedBriefSystemOverview];
    }
}
    
}
