// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../MainWindowFilePanelState.h"
#include "../PanelController.h"
#include "BatchRename.h"
#include "../PanelData.h"
#include "../PanelView.h"
#include "../../MainWindowController.h"
#include <Operations/BatchRenaming.h>
#include <Operations/BatchRenamingDialog.h>
#include <NimbleCommander/Core/SimpleComboBoxPersistentDataSource.h>

namespace nc::panel::actions {

static const auto g_ConfigPatternsPath = "filePanel.batchRename.lastPatterns";
static const auto g_ConfigSearchesPath = "filePanel.batchRename.lastSearches";
static const auto g_ConfigReplacesPath = "filePanel.batchRename.lastReplaces";

bool BatchRename::Predicate( PanelController *_target ) const
{
    auto i = _target.view.item;
    return ( !_target.isUniform || _target.vfs->IsWritable() ) &&
           i &&
           (!i.IsDotDot() || _target.data.Stats().selected_entries_amount > 0);
    return true;
}

void BatchRename::Perform( PanelController *_target, id _sender ) const
{
    const auto items = _target.selectedEntriesOrFocusedEntry;
    if( items.empty() )
        return;
    
    const auto host = items.front().Host();
    if( !all_of(begin(items), end(items), [=](auto &i){ return i.Host() == host;}) )
        return; // currently BatchRenameOperation supports only single host for items    
    
    const auto sheet = [[NCOpsBatchRenamingDialog alloc] initWithItems:move(items)];
    sheet.renamePatternDataSource = [[SimpleComboBoxPersistentDataSource alloc]
                                     initWithStateConfigPath:g_ConfigPatternsPath];
    sheet.searchForDataSource = [[SimpleComboBoxPersistentDataSource alloc]
                                     initWithStateConfigPath:g_ConfigSearchesPath];
    sheet.replaceWithDataSource = [[SimpleComboBoxPersistentDataSource alloc]
                                     initWithStateConfigPath:g_ConfigReplacesPath];

    [_target.mainWindowController beginSheet:sheet.window
                           completionHandler:^(NSModalResponse returnCode) {
        if( returnCode == NSModalResponseOK ) {
            auto src_paths = sheet.filenamesSource;
            auto dst_paths = sheet.filenamesDestination;


            const auto operation = make_shared<nc::ops::BatchRenaming>(move(src_paths),
                                                                       move(dst_paths),
                                                                       host);
            if( !_target.receivesUpdateNotifications ) {
                __weak PanelController *weak_panel = _target;
                operation->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish,[=]{
                    dispatch_to_main_queue( [=]{
                        [(PanelController*)weak_panel refreshPanel];
                    });
                });
            }
            
            [_target.mainWindowController enqueueOperation:operation];
        }
    }];
}

}



