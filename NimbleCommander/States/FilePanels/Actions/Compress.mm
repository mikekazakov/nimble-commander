// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Compress.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../PanelData.h"
#include "../MainWindowFilePanelState.h"
#include "../../MainWindowController.h"
#include <VFS/VFS.h>
#include <Utility/PathManip.h>
#include <Operations/Compression.h>
#include <Operations/CompressDialog.h>
#include <Habanero/dispatch_cpp.h>

namespace nc::panel::actions {

static PanelController *FindVisibleOppositeController( PanelController *_source );
static void FocusResult(PanelController *_target,
                        const std::shared_ptr<nc::ops::Compression>& _op );

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

void CompressHere::Perform( PanelController *_target, id ) const
{
    auto entries = _target.selectedEntriesOrFocusedEntry;
    if( entries.empty() )
        return;

    auto dialog = [[NCOpsCompressDialog alloc] initWithItems:entries
                                              destinationVFS:_target.vfs 
                                          initialDestination:_target.currentDirectoryPath];
    
    const auto handler = ^(NSModalResponse returnCode){
        if( returnCode != NSModalResponseOK )
            return;
        
        auto op = std::make_shared<nc::ops::Compression>(entries,
                                                         dialog.destination,
                                                         _target.vfs,
                                                         dialog.password);
        const auto weak_op = std::weak_ptr<nc::ops::Compression>{op};
        __weak PanelController *weak_target = _target;
        op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [weak_target, weak_op] {
            FocusResult((PanelController*)weak_target, weak_op.lock());
        });
        
        [_target.mainWindowController enqueueOperation:op];
    };
    
    [_target.mainWindowController beginSheet:dialog.window completionHandler:handler];
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

void CompressToOpposite::Perform( PanelController *_target, id ) const
{
    const auto opposite_panel = FindVisibleOppositeController(_target);
    if( !opposite_panel.isUniform || !opposite_panel.vfs->IsWritable() )
        return;
    
    auto entries = _target.selectedEntriesOrFocusedEntry;
    if(entries.empty())
        return;
    
    auto dialog = [[NCOpsCompressDialog alloc] initWithItems:entries
                                              destinationVFS:opposite_panel.vfs 
                                          initialDestination:opposite_panel.currentDirectoryPath];
    
    const auto handler = ^(NSModalResponse returnCode){
        if( returnCode != NSModalResponseOK )
            return;
                
        auto op = std::make_shared<nc::ops::Compression>(entries,
                                                         dialog.destination,
                                                         opposite_panel.vfs,
                                                         dialog.password);
        const auto weak_op = std::weak_ptr<nc::ops::Compression>{op};
        __weak PanelController *weak_target = opposite_panel;
        op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [weak_target, weak_op] {
            FocusResult((PanelController*)weak_target, weak_op.lock());
        });
        
        [_target.mainWindowController enqueueOperation:op];
    };
    
    [_target.mainWindowController beginSheet:dialog.window completionHandler:handler];
}

context::CompressHere::CompressHere(const std::vector<VFSListingItem>&_items):
    m_Items(_items)
{
}

bool context::CompressHere::Predicate( PanelController *_target ) const
{
    return _target.isUniform && _target.vfs->IsWritable();
}

bool context::CompressHere::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    if(m_Items.size() > 1)
        _item.title = [NSString stringWithFormat:
            NSLocalizedStringFromTable(@"Compress %lu Items",
                                       @"FilePanelsContextMenu",
                                       "Compress some items here"),
            m_Items.size()];
    else
        _item.title = [NSString stringWithFormat:
            NSLocalizedStringFromTable(@"Compress \u201c%@\u201d",
                                       @"FilePanelsContextMenu",
                                       "Compress one item here"),
            m_Items.front().DisplayNameNS()];

    return Predicate(_target);
}

void context::CompressHere::Perform( PanelController *_target, id ) const
{
    auto entries = m_Items;
    auto op = std::make_shared<nc::ops::Compression>(std::move(entries),
                                                     _target.currentDirectoryPath,
                                                     _target.vfs);

    const auto weak_op = std::weak_ptr<nc::ops::Compression>{op};
    __weak PanelController *weak_target = _target;
    op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [weak_target, weak_op] {
        FocusResult((PanelController*)weak_target, weak_op.lock());
    });

    [_target.mainWindowController enqueueOperation:op];

}

context::CompressToOpposite::CompressToOpposite(const std::vector<VFSListingItem>&_items):
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

bool context::CompressToOpposite::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    if(m_Items.size() > 1)
        _item.title = [NSString stringWithFormat:
            NSLocalizedStringFromTable(@"Compress %lu Items in Opposite Panel",
                                       @"FilePanelsContextMenu",
                                       "Compress some items"),
            m_Items.size()];
    else
        _item.title = [NSString stringWithFormat:
            NSLocalizedStringFromTable(@"Compress \u201c%@\u201d in Opposite Panel",
                                       @"FilePanelsContextMenu",
                                       "Compress one item"),
            m_Items.front().DisplayNameNS()];

    
    return Predicate(_target);
}

void context::CompressToOpposite::Perform( PanelController *_target, id ) const
{
    const auto opposite_panel = FindVisibleOppositeController(_target);
    if( !opposite_panel.isUniform || !opposite_panel.vfs->IsWritable() )
        return;
    
    auto entries = m_Items;
    auto op = std::make_shared<nc::ops::Compression>(std::move(entries),
                                                     opposite_panel.currentDirectoryPath,
                                                     opposite_panel.vfs);
    const auto weak_op = std::weak_ptr<nc::ops::Compression>{op};
    __weak PanelController *weak_target = opposite_panel;
    op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [weak_target, weak_op] {
        FocusResult((PanelController*)weak_target, weak_op.lock());
    });

    [_target.mainWindowController enqueueOperation:op];
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

static void FocusResult(PanelController *_target,
                        const std::shared_ptr<nc::ops::Compression>& _op )
{
    if( !_target || !_op )
        return;
    
    if( dispatch_is_main_queue() ) {
        const auto result_path = boost::filesystem::path(_op->ArchivePath());
        const auto directory =  EnsureTrailingSlash(result_path.parent_path().native());
        const auto filename = result_path.filename().native();
        if( _target.isUniform && _target.currentDirectoryPath == directory ) {
            [_target refreshPanel];
            nc::panel::DelayedFocusing req;
            req.filename = filename;
            [_target scheduleDelayedFocusing:req];
        }
    }
    else
        dispatch_to_main_queue([_target, _op]{
            FocusResult(_target, _op);
        });
}

}
