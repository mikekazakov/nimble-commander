// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
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

void RevealInOppositePanel::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    const auto current = _target.activePanelController;
    const auto opposite = _target.oppositePanelController;
    if( !current || !opposite )
        return;
    
    const auto item = current.view.item;
    if( !item )
        return;
    
    if( item.IsDir() )
        [opposite GoToDir:item.Path()
                      vfs:item.Host()
             select_entry:""
                    async:true];
    else
        [opposite GoToDir:item.Directory()
                      vfs:item.Host()
             select_entry:item.Filename()
                    async:true];
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
    
    if( item.IsDir() )
        [opposite GoToDir:item.Path()
                      vfs:item.Host()
             select_entry:""
                    async:true];
    else
        [opposite GoToDir:item.Directory()
                      vfs:item.Host()
             select_entry:item.Filename()
                    async:true];
}

}
