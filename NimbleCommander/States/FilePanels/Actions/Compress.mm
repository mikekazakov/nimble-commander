#include "Compress.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../MainWindowFilePanelState.h"
#include <VFS/VFS.h>
#include <NimbleCommander/Operations/Compress/FileCompressOperation.h>

namespace nc::panel::actions {

static PanelController *FindVisibleOppositeController( PanelController *_source );

bool CompressHere::Predicate( PanelController *_target ) const
{
    if( !_target.isUniform )
        return false;
    
    const auto i = _target.view.item;
    return i && !i.IsDotDot();
}

void CompressHere::Perform( PanelController *_target, id _sender ) const
{
    auto entries = _target.selectedEntriesOrFocusedEntry;
    if( entries.empty() )
        return;
    
    auto op = [[FileCompressOperation alloc] initWithFiles:move(entries)
                                                   dstroot:_target.currentDirectoryPath
                                                    dstvfs:_target.vfs];
    op.TargetPanel = _target;
    [_target.state AddOperation:op];
}

bool CompressToOpposite::Predicate( PanelController *_target ) const
{
    if( !_target.isUniform )
        return false;
    
    const auto i = _target.view.item;
    if( !i || i.IsDotDot() )
        return false;

    return FindVisibleOppositeController(_target).isUniform;
}

void CompressToOpposite::Perform( PanelController *_target, id _sender ) const
{
    const auto opposite_panel = FindVisibleOppositeController(_target);
    if( !opposite_panel.isUniform )
        return;
    
    auto entries = _target.selectedEntriesOrFocusedEntry;
    if(entries.empty())
        return;

    const auto op = [[FileCompressOperation alloc] initWithFiles:move(entries)
                                                         dstroot:opposite_panel.currentDirectoryPath
                                                          dstvfs:opposite_panel.vfs];
    op.TargetPanel = opposite_panel;
    [_target.state AddOperation:op];
}

static PanelController *FindVisibleOppositeController( PanelController *_source )
{
    auto state = _source.state;
    if( !state.bothPanelsAreVisible )
        return nil;
    if( [state isLeftController:_source] )
        return state.rightPanelController;
    if( [state isRightController:_source] )
        return state.leftPanelController;
    return nil;
}

}
