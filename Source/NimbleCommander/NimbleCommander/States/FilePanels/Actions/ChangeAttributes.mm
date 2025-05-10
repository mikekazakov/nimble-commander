// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ChangeAttributes.h"
#include <Base/algo.h>
#include <Base/dispatch_cpp.h>
#include <VFS/VFS.h>
#include "../PanelController.h"
#include <Panel/PanelData.h>
#include "../PanelView.h"
#include "../../MainWindowController.h"
#include <Operations/AttrsChangingDialog.h>
#include <Operations/AttrsChanging.h>
#include "Helpers.h"

namespace nc::panel::actions {

static const auto g_DeselectConfigFlag = "filePanel.general.deselectItemsAfterFileOperations";

ChangeAttributes::ChangeAttributes(nc::config::Config &_config) : m_Config(_config)
{
}

bool ChangeAttributes::Predicate(PanelController *_target) const
{
    // checks that there's an item or items to operate on, they have the same host and that host supports changing
    // attributes
    VFSHostPtr host;
    const nc::panel::data::Model &data = _target.data;
    if( data.Stats().selected_entries_amount == 0 ) {
        // Simplest form - nothing is selected, just get the focused item and check it
        const VFSListingItem item = _target.view.item;
        if( !item || item.IsDotDot() )
            return false;
        host = item.Host();
    }
    else if( data.Listing().HasCommonHost() ) {
        // There are selected items => need to check them, but the listing has the common host => get it from the
        // listing
        host = data.Listing().Host();
    }
    else {
        // The most expensive check - need to check each selected item
        for( unsigned ind : data.SortedDirectoryEntries() ) {
            if( data.VolatileDataAtRawPosition(ind).is_selected() )
                if( VFSListingItem e = data.EntryAtRawPosition(ind) ) {
                    if( host == nullptr ) {
                        host = e.Host();
                    }
                    else if( host != e.Host() ) {
                        return false; // Can't operate on a set of different hosts
                    }
                }
        }
    }
    if( !host )
        return false; // failsafe - something is wrong

    return [NCOpsAttrsChangingDialog canEditAnythingInHost:*host];
}

void ChangeAttributes::Perform(PanelController *_target, [[maybe_unused]] id _sender) const
{
    auto items = _target.selectedEntriesOrFocusedEntry;
    if( ![NCOpsAttrsChangingDialog canEditAnythingInItems:items] )
        return;

    const auto sheet = [[NCOpsAttrsChangingDialog alloc] initWithItems:std::move(items)];

    const auto handler = ^(NSModalResponse returnCode) {
      if( returnCode != NSModalResponseOK )
          return;

      const auto op = std::make_shared<nc::ops::AttrsChanging>(sheet.command);
      __weak PanelController *weak_panel = _target;
      op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=] {
          dispatch_to_main_queue([=] {
              if( PanelController *const pc = weak_panel )
                  [pc refreshPanel];
          });
      });

      if( m_Config.GetBool(g_DeselectConfigFlag) ) {
          const auto deselector = std::make_shared<const DeselectorViaOpNotification>(_target);
          op->SetItemStatusCallback([deselector](nc::ops::ItemStateReport _report) { deselector->Handle(_report); });
      }

      [_target.mainWindowController enqueueOperation:op];
    };

    [_target.mainWindowController beginSheet:sheet.window completionHandler:handler];
}

} // namespace nc::panel::actions
