// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Delete.h"
#include "../PanelController.h"
#include "../MainWindowFilePanelState.h"
#include <Utility/NativeFSManager.h>
#include <Habanero/algo.h>
#include "../PanelData.h"
#include "../PanelView.h"
#include <Operations/Deletion.h>
#include <Operations/DeletionDialog.h>
#include "../../MainWindowController.h"
#include <unordered_set>
#include <Habanero/dispatch_cpp.h>

namespace nc::panel::actions {

static bool CommonDeletePredicate( PanelController *_target );
static bool AllAreNative(const std::vector<VFSListingItem>& _c);
static std::unordered_set<std::string> ExtractDirectories(const std::vector<VFSListingItem>& _c);
static bool AllHaveTrash(const std::vector<VFSListingItem>& _c);
static void AddPanelRefreshEpilogIfNeeded(PanelController *_target,
                                          const std::shared_ptr<nc::ops::Operation> &_operation );

Delete::Delete( bool _permanently ):
    m_Permanently(_permanently)
{
}

bool Delete::Predicate( PanelController *_target ) const
{
    return CommonDeletePredicate(_target);
}

void Delete::Perform( PanelController *_target, id ) const
{
    auto items = to_shared_ptr(_target.selectedEntriesOrFocusedEntry);
    if( items->empty() )
        return;
    
    const auto sheet = [[NCOpsDeletionDialog alloc] initWithItems:items];
    if( AllAreNative(*items) ) {
        const auto all_have_trash = AllHaveTrash(*items);
        sheet.allowMoveToTrash = all_have_trash;
        sheet.defaultType = m_Permanently ?
            nc::ops::DeletionType::Permanent :
            (all_have_trash ?
                nc::ops::DeletionType::Trash :
                nc::ops::DeletionType::Permanent);
    }
    else {
        sheet.allowMoveToTrash = false;
        sheet.defaultType = nc::ops::DeletionType::Permanent;
    }

    auto sheet_handler = ^(NSModalResponse returnCode) {
        if( returnCode == NSModalResponseOK ){
            const auto operation = std::make_shared<nc::ops::Deletion>(
                move(*items),
                sheet.resultType);
            AddPanelRefreshEpilogIfNeeded(_target, operation);
            [_target.mainWindowController enqueueOperation:operation];
        }
    };
    
    [_target.mainWindowController beginSheet:sheet.window completionHandler:sheet_handler];
}

bool MoveToTrash::Predicate( PanelController *_target ) const
{
    return CommonDeletePredicate(_target);
}

void MoveToTrash::Perform( PanelController *_target, id _sender ) const
{
    auto items = _target.selectedEntriesOrFocusedEntry;
    
    if( !AllAreNative(items) ) {
        // instead of trying to silently reap files on VFS like FTP
        // (that means we'll erase it, not move to trash),
        // forward the request as a regular F8 delete
        Delete{}.Perform(_target, _sender);
        return;
    }
    
    if( !AllHaveTrash(items) ) {
        // if user called MoveToTrash by cmd+backspace but there's no trash on this volume:
        // show a dialog and ask him to delete a file permanently
        Delete{true}.Perform(_target, _sender);
        return;
    }

    const auto operation = std::make_shared<nc::ops::Deletion>(move(items),
                                                          nc::ops::DeletionType::Trash);
    AddPanelRefreshEpilogIfNeeded(_target, operation);
    [_target.mainWindowController enqueueOperation:operation];
}

context::MoveToTrash::MoveToTrash(const std::vector<VFSListingItem> &_items):
    m_Items(_items)
{
    m_AllAreNative = AllAreNative(m_Items);
}

bool context::MoveToTrash::Predicate( PanelController * ) const
{
    return m_AllAreNative;
}

void context::MoveToTrash::Perform( PanelController *_target, id ) const
{
    const auto operation = std::make_shared<nc::ops::Deletion>(m_Items,
                                                          nc::ops::DeletionType::Trash);
    AddPanelRefreshEpilogIfNeeded(_target, operation);
    [_target.mainWindowController enqueueOperation:operation];
}

context::DeletePermanently::DeletePermanently(const std::vector<VFSListingItem> &_items):
    m_Items(_items)
{
    m_AllWriteable = all_of(begin(m_Items), end(m_Items), [](const auto &i){
        return i.Host()->IsWritable();
    });
}

bool context::DeletePermanently::Predicate( PanelController * ) const
{
    return m_AllWriteable;
}

void context::DeletePermanently::Perform( PanelController *_target, id ) const
{
    const auto operation = std::make_shared<nc::ops::Deletion>(m_Items,
                                                          nc::ops::DeletionType::Permanent);
    AddPanelRefreshEpilogIfNeeded(_target, operation);
    [_target.mainWindowController enqueueOperation:operation];
}

static bool CommonDeletePredicate( PanelController *_target )
{
    auto i = _target.view.item;
    if( !i || !i.Host()->IsWritable() )
        return false;
    return !i.IsDotDot() || _target.data.Stats().selected_entries_amount > 0;
}

static bool AllAreNative(const std::vector<VFSListingItem>& _c)
{
    return all_of(begin(_c), end(_c), [&](auto &i){
        return i.Host()->IsNativeFS();
    });
}

static std::unordered_set<std::string> ExtractDirectories(const std::vector<VFSListingItem>& _c)
{
    std::unordered_set<std::string> directories;
    for(const auto &i: _c)
        directories.emplace( i.Directory() );
    return directories;
}

static bool AllHaveTrash(const std::vector<VFSListingItem>& _c)
{
    const auto directories = ExtractDirectories(_c);
    return all_of(begin(directories), end(directories), [](auto &i){
        if( auto vol = utility::NativeFSManager::Instance().VolumeFromPath(i) )
            if( vol->interfaces.has_trash )
                return true;
        return false;
    });
}


static void AddPanelRefreshEpilogIfNeeded(PanelController *_target,
                                          const std::shared_ptr<nc::ops::Operation> &_operation )
{
    if( !_target.receivesUpdateNotifications ) {
        __weak PanelController *weak_panel = _target;
        _operation->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, [=]{
            dispatch_to_main_queue( [=]{
                [(PanelController*)weak_panel refreshPanel];
            });
        });
    }
}


}
