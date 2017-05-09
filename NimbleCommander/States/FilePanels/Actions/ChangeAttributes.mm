#include <Habanero/algo.h>
#include <NimbleCommander/Operations/Attrs/FileSysAttrChangeOperation.h>
#include <NimbleCommander/Operations/Attrs/FileSysEntryAttrSheetController.h>
#include <NimbleCommander/Operations/Attrs/FileSysAttrChangeOperationCommand.h>
#include "../PanelController.h"
#include "../MainWindowFilePanelState.h"
#include "ChangeAttributes.h"
#include "../PanelData.h"
#include "../PanelView.h"

namespace nc::panel::actions {

bool ChangeAttributes::Predicate( PanelController *_target ) const
{
    auto i = _target.view.item;
    return i &&
        ( (!i.IsDotDot() && i.Host()->IsNativeFS()) ||
            _target.data.Stats().selected_entries_amount > 0 );
}

void ChangeAttributes::Perform( PanelController *_target, id _sender ) const
{
    auto entries = to_shared_ptr(_target.selectedEntriesOrFocusedEntry);
    if( entries->empty() )
        return;
    if( !all_of(begin(*entries), end(*entries), [](auto &i){ return i.Host()->IsNativeFS(); }) )
        return;
    
    FileSysEntryAttrSheetController *sheet = [[FileSysEntryAttrSheetController alloc] initWithItems:entries];
    [sheet beginSheetForWindow:_target.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode == NSModalResponseOK ) {
            auto operation = [[FileSysAttrChangeOperation alloc] initWithCommand:*sheet.result];
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
