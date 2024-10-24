// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BatchRename.h"
#include "../MainWindowFilePanelState.h"
#include "../PanelController.h"
#include <Panel/PanelData.h>
#include "../PanelView.h"
#include "../../MainWindowController.h"
#include <Operations/BatchRenaming.h>
#include <Operations/BatchRenamingDialog.h>
#include <NimbleCommander/Core/SimpleComboBoxPersistentDataSource.h>
#include <Base/dispatch_cpp.h>
#include <algorithm>

namespace nc::panel::actions {

static const auto g_ConfigPatternsPath = "filePanel.batchRename.lastPatterns";
static const auto g_ConfigSearchesPath = "filePanel.batchRename.lastSearches";
static const auto g_ConfigReplacesPath = "filePanel.batchRename.lastReplaces";

bool BatchRename::Predicate(PanelController *_target) const
{
    auto i = _target.view.item;
    return (!_target.isUniform || _target.vfs->IsWritable()) && i &&
           (!i.IsDotDot() || _target.data.Stats().selected_entries_amount > 0);
    return true;
}

void BatchRename::Perform(PanelController *_target, id /*_sender*/) const
{
    const auto items = _target.selectedEntriesOrFocusedEntry;
    if( items.empty() )
        return;

    const auto host = items.front().Host();
    if( !std::ranges::all_of(items, [=](auto &i) { return i.Host() == host; }) )
        return; // currently BatchRenameOperation supports only single host for items

    const auto sheet = [[NCOpsBatchRenamingDialog alloc] initWithItems:items];
    sheet.renamePatternDataSource =
        [[SimpleComboBoxPersistentDataSource alloc] initWithStateConfigPath:g_ConfigPatternsPath];
    sheet.searchForDataSource =
        [[SimpleComboBoxPersistentDataSource alloc] initWithStateConfigPath:g_ConfigSearchesPath];
    sheet.replaceWithDataSource =
        [[SimpleComboBoxPersistentDataSource alloc] initWithStateConfigPath:g_ConfigReplacesPath];

    auto handler = ^(NSModalResponse returnCode) {
      if( returnCode == NSModalResponseOK ) {
          auto src_paths = sheet.filenamesSource;
          auto dst_paths = sheet.filenamesDestination;

          const auto operation =
              std::make_shared<nc::ops::BatchRenaming>(std::move(src_paths), std::move(dst_paths), host);
          __weak PanelController *weak_panel = _target;
          operation->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, [=] {
              dispatch_to_main_queue([=] {
                  if( PanelController *const pc = weak_panel )
                      [pc hintAboutFilesystemChange];
              });
          });

          [_target.mainWindowController enqueueOperation:operation];
      }
    };

    [_target.mainWindowController beginSheet:sheet.window completionHandler:handler];
}

} // namespace nc::panel::actions
