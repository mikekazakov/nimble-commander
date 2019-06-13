// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
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
    
void SyncPanels::Perform( MainWindowFilePanelState *_target, id ) const
{
    if( _target.splitView.anyCollapsedOrOverlayed )
        return;
    
    const auto current = _target.activePanelController;
    const auto opposite = _target.oppositePanelController;
    
    if( !current || !opposite )
        return;
    
    if( current.isUniform ) {
        auto request = std::make_shared<DirectoryChangeRequest>();
        request->RequestedDirectory = current.currentDirectoryPath;
        request->VFS = current.vfs;
        request->PerformAsynchronous = true;
        request->InitiatedByUser = true;
        [opposite GoToDirWithContext:request];
    }
    else {
        [opposite loadListing:current.data.ListingPtr()];
    }
}

bool SwapPanels::Predicate( MainWindowFilePanelState *_target ) const
{
    return _target.isPanelActive && !_target.splitView.anyCollapsedOrOverlayed;
}

void SwapPanels::Perform( MainWindowFilePanelState *_target, id ) const
{
    [_target swapPanels];
}
    
}
