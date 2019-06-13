// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ShowQuickLook.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../MainWindowFilePanelState.h"
#include "../PanelAux.h"

namespace nc::panel::actions {

bool ShowQuickLook::Predicate( PanelController *_target ) const
{
    if( !_target.view.item )
        return false;

    if( ShowQuickLookAsFloatingPanel() )
        return true;
    
    if( _target.state.anyPanelCollapsed )
        return false;
    
    return true;
}
        
void ShowQuickLook::Perform( PanelController *_target, [[maybe_unused]] id _sender ) const
{
    const auto state = _target.state;
    if( [state quickLookForPanel:_target make:false] ) {
        [state closeAttachedUI:_target];
    }
    else {
        if( [state quickLookForPanel:_target make:true] )
            [_target updateAttachedQuickLook];
    }
}
    
}
