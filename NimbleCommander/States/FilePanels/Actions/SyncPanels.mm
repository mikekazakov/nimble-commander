// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SyncPanels.h"
#include "../MainWindowFilePanelState.h"
#include "../PanelController.h"
#include "../PanelData.h"
#include "../Views/FilePanelMainSplitView.h"

namespace nc::panel::actions {

bool SyncPanels::Predicate( MainWindowFilePanelState *_target ) const
{
    const auto act_pc = _target.activePanelController;
    if( !act_pc )
        return false;
    
    if( _target.splitView.anyCollapsedOrOverlayed )
        return false;
    
    return true;
}
    
void SyncPanels::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    if( _target.splitView.anyCollapsedOrOverlayed )
        return;
    
    const auto cur = _target.activePanelController;
    const auto opp = _target.oppositePanelController;
    
    if( !cur || !opp )
        return;
    
    if( cur.isUniform ) {
        [opp GoToDir:cur.currentDirectoryPath
                 vfs:cur.vfs
        select_entry:""
               async:true];
    }
    else {
        [opp loadListing:cur.data.ListingPtr()];
    }
}

bool SwapPanels::Predicate( MainWindowFilePanelState *_target ) const
{
    return _target.isPanelActive && !_target.splitView.anyCollapsedOrOverlayed;
}

void SwapPanels::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    [_target swapPanels];
}
    
}
