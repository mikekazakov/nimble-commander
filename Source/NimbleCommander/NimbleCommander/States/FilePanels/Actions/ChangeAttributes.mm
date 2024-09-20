// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
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
    const auto i = _target.view.item;
    return i && ((!i.IsDotDot() && i.Host()->IsWritable()) || _target.data.Stats().selected_entries_amount > 0);
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
