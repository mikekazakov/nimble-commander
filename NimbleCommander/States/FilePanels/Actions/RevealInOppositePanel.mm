// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "RevealInOppositePanel.h"
#include "../MainWindowFilePanelState.h"
#include "../MainWindowFilePanelState+TabsSupport.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../Views/FilePanelMainSplitView.h"

namespace nc::panel::actions {

bool RevealInOppositePanel::Predicate( MainWindowFilePanelState *_target ) const
{
    const auto pc = _target.activePanelController;
    if( !pc )
        return false;
    
    if( !pc.view.item )
        return false;
    
    if( _target.splitView.anyCollapsedOrOverlayed )
        return false;
    
    return true;
}
    
static void RevealItem(const VFSListingItem &_item, PanelController *_panel)
{
    auto request = std::make_shared<DirectoryChangeRequest>();
    request->VFS = _item.Host();
    if( _item.IsDir() ) {
        request->RequestedDirectory = _item.Path();
    }
    else {
        request->RequestedDirectory = _item.Directory();
        request->RequestFocusedEntry = _item.Filename();
    }
    request->PerformAsynchronous = true;
    request->InitiatedByUser = true;
    [_panel GoToDirWithContext:request];
}

void RevealInOppositePanel::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    const auto current = _target.activePanelController;
    const auto opposite = _target.oppositePanelController;
    if( !current || !opposite )
        return;
    
    const auto item = current.view.item;
    if( !item )
        return;

    RevealItem(item, opposite);
}

bool RevealInOppositePanelTab::Predicate( MainWindowFilePanelState *_target ) const
{
    const auto pc = _target.activePanelController;
    if( !pc )
        return false;
    
    if( !pc.view.item )
        return false;
    
    if( _target.splitView.anyCollapsedOrOverlayed )
        return false;
    
    return true;
}

static PanelController *SpawnOppositeTab(MainWindowFilePanelState *_target,
                                         PanelController *_current )
{
    if( _current == _target.leftPanelController )
        return [_target spawnNewTabInTabView:_target.splitView.rightTabbedHolder.tabView
                        autoDirectoryLoading:false
                            activateNewPanel:false];
    else if( _current == _target.rightPanelController )
        return [_target spawnNewTabInTabView:_target.splitView.leftTabbedHolder.tabView
                        autoDirectoryLoading:false
                            activateNewPanel:false];
    return nil;
}

void RevealInOppositePanelTab::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    const auto current = _target.activePanelController;
    if( !current )
        return;
    
    const auto item = current.view.item;
    if( !item )
        return;
    
    const auto opposite = SpawnOppositeTab(_target, current);
    if( !opposite )
        return;

    RevealItem(item, opposite);
}

}
