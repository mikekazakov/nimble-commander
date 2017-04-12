#include <NimbleCommander/Operations/BatchRename/BatchRename.h>
#include <NimbleCommander/Operations/BatchRename/BatchRenameSheetController.h>
#include <NimbleCommander/Operations/BatchRename/BatchRenameOperation.h>
#include "../MainWindowFilePanelState.h"
#include "../PanelController.h"
#include "BatchRename.h"

namespace panel::actions {

bool BatchRename::Predicate( PanelController *_target )
{
    auto i = _target.view.item;
    return ( !_target.isUniform || _target.vfs->IsWritable() ) &&
           i &&
           (!i.IsDotDot() || _target.data.Stats().selected_entries_amount > 0);
    return true;
}

bool BatchRename::ValidateMenuItem( PanelController *_target, NSMenuItem *_item )
{
    return Predicate(_target);
}

void BatchRename::Perform( PanelController *_target, id _sender )
{
    const auto items = _target.selectedEntriesOrFocusedEntry;
    if( items.empty() )
        return;
    
    const auto host = items.front().Host();
    if( !all_of(begin(items), end(items), [=](auto &i){ return i.Host() == host;}) )
        return; // currently BatchRenameOperation supports only single host for items    
    
    const auto sheet = [[BatchRenameSheetController alloc] initWithItems:move(items)];
    [sheet beginSheetForWindow:_target.window
             completionHandler:^(NSModalResponse returnCode) {
        if( returnCode == NSModalResponseOK ) {
            auto src_paths = sheet.filenamesSource;
            auto dst_paths = sheet.filenamesDestination;

            auto operation = [[BatchRenameOperation alloc]
                              initWithOriginalFilepaths:move(src_paths)
                              renamedFilepaths:move(dst_paths)
                              vfs:host];
            if( !_target.receivesUpdateNotifications ) {
                __weak PanelController *weak_panel = _target;
                [operation AddOnFinishHandler:[=]{
                    dispatch_to_main_queue( [=]{
                        [(PanelController*)weak_panel refreshPanel];
                    });
                }];
            }
            
            [_target.state AddOperation:operation];
        }
    }];
}

}



