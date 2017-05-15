#include "Compress.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../PanelData.h"
#include "../MainWindowFilePanelState.h"
#include <VFS/VFS.h>
#include <NimbleCommander/Operations/Compress/FileCompressOperation.h>

namespace nc::panel::actions {

static PanelController *FindVisibleOppositeController( PanelController *_source );

bool CompressHere::Predicate( PanelController *_target ) const
{
    if( !_target.isUniform )
        return false;
    
    if( !_target.vfs->IsWritable() )
        return false;
    
    const auto i = _target.view.item;
    if( !i )
        return false;
    
    return !i.IsDotDot() || _target.data.Stats().selected_entries_amount > 0;
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
    const auto i = _target.view.item;
    if( !i )
        return false;
    if( i.IsDotDot() && _target.data.Stats().selected_entries_amount == 0 )
        return false;

    auto opposite = FindVisibleOppositeController(_target);
    if( !opposite )
        return false;
    
    return opposite.isUniform && opposite.vfs->IsWritable();
}

void CompressToOpposite::Perform( PanelController *_target, id _sender ) const
{
    const auto opposite_panel = FindVisibleOppositeController(_target);
    if( !opposite_panel.isUniform || !opposite_panel.vfs->IsWritable() )
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

context::CompressHere::CompressHere(const vector<VFSListingItem>&_items):
    m_Items(_items)
{
}

bool context::CompressHere::Predicate( PanelController *_target ) const
{
    return _target.isUniform && _target.vfs->IsWritable();
}

void context::CompressHere::Perform( PanelController *_target, id _sender ) const
{
    auto entries = m_Items;
    auto op = [[FileCompressOperation alloc] initWithFiles:move(entries)
                                                   dstroot:_target.currentDirectoryPath
                                                    dstvfs:_target.vfs];
    op.TargetPanel = _target;
    [_target.state AddOperation:op];
}

context::CompressToOpposite::CompressToOpposite(const vector<VFSListingItem>&_items):
    m_Items(_items)
{
}

bool context::CompressToOpposite::Predicate( PanelController *_target ) const
{
    auto opposite = FindVisibleOppositeController(_target);
    if( !opposite )
        return false;
    
    return opposite.isUniform && opposite.vfs->IsWritable();
}

void context::CompressToOpposite::Perform( PanelController *_target, id _sender ) const
{
    const auto opposite_panel = FindVisibleOppositeController(_target);
    if( !opposite_panel.isUniform || !opposite_panel.vfs->IsWritable() )
        return;
    
    auto entries = m_Items;
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
