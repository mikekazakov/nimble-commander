// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ChangeAttributes.h"
#include <Habanero/algo.h>
#include <Habanero/dispatch_cpp.h>
#include <VFS/VFS.h>
#include "../PanelController.h"
#include "../PanelData.h"
#include "../PanelView.h"
#include "../../MainWindowController.h"
#include <Operations/AttrsChangingDialog.h>
#include <Operations/AttrsChanging.h>

namespace nc::panel::actions {

bool ChangeAttributes::Predicate( PanelController *_target ) const
{
    const auto i = _target.view.item;
    return i &&
        ((!i.IsDotDot() && i.Host()->IsWritable()) ||
         _target.data.Stats().selected_entries_amount > 0 );
}

void ChangeAttributes::Perform( PanelController *_target, [[maybe_unused]] id _sender ) const
{
    auto items = _target.selectedEntriesOrFocusedEntry;
    if( ![NCOpsAttrsChangingDialog canEditAnythingInItems:items] )
        return;
    
    const auto sheet = [[NCOpsAttrsChangingDialog alloc] initWithItems:move(items)];
    
    const auto handler = ^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;

        const auto op = std::make_shared<nc::ops::AttrsChanging>(sheet.command);
        if( !_target.receivesUpdateNotifications ) {
            __weak PanelController *weak_panel = _target;
            op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=]{
                dispatch_to_main_queue( [=]{
                    [(PanelController*)weak_panel refreshPanel];
                });
            });
        }
        
        [_target.mainWindowController enqueueOperation:op];
    };
    
    [_target.mainWindowController beginSheet:sheet.window
                           completionHandler:handler];
}

}
