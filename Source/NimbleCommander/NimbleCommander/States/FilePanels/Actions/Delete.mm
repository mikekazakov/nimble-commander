// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Delete.h"
#include "../PanelController.h"
#include "../MainWindowFilePanelState.h"
#include <Utility/NativeFSManager.h>
#include <Base/algo.h>
#include <Panel/PanelData.h>
#include "../PanelView.h"
#include <Operations/Deletion.h>
#include <Operations/DeletionDialog.h>
#include "../../MainWindowController.h"
#include <ankerl/unordered_dense.h>
#include <Base/dispatch_cpp.h>

#include <algorithm>

namespace nc::panel::actions {

static bool CommonDeletePredicate(PanelController *_target);
static bool AllAreNative(const std::vector<VFSListingItem> &_c);
static ankerl::unordered_dense::set<std::string> ExtractDirectories(const std::vector<VFSListingItem> &_c);
static bool TryTrash(const std::vector<VFSListingItem> &_c, utility::NativeFSManager &_fsman);
static void AddPanelRefreshEpilog(PanelController *_target, nc::ops::Operation &_operation);

Delete::Delete(nc::utility::NativeFSManager &_nat_fsman, bool _permanently)
    : m_NativeFSManager{_nat_fsman}, m_Permanently(_permanently)
{
}

bool Delete::Predicate(PanelController *_target) const
{
    return CommonDeletePredicate(_target);
}

void Delete::Perform(PanelController *_target, id /*_sender*/) const
{
    auto items = to_shared_ptr(_target.selectedEntriesOrFocusedEntry);
    if( items->empty() )
        return;

    const auto sheet = [[NCOpsDeletionDialog alloc] initWithItems:items];
    if( AllAreNative(*items) ) {
        const auto try_trash = TryTrash(*items, m_NativeFSManager);
        sheet.allowMoveToTrash = try_trash;
        sheet.defaultType = [&] {
            if( m_Permanently )
                return nc::ops::DeletionType::Permanent;
            else
                return try_trash ? nc::ops::DeletionType::Trash : nc::ops::DeletionType::Permanent;
        }();
    }
    else {
        sheet.allowMoveToTrash = false;
        sheet.defaultType = nc::ops::DeletionType::Permanent;
    }

    auto sheet_handler = ^(NSModalResponse returnCode) {
      if( returnCode == NSModalResponseOK ) {
          const auto operation = std::make_shared<nc::ops::Deletion>(std::move(*items), sheet.resultType);
          AddPanelRefreshEpilog(_target, *operation);
          [_target.mainWindowController enqueueOperation:operation];
      }
    };

    [_target.mainWindowController beginSheet:sheet.window completionHandler:sheet_handler];
}

MoveToTrash::MoveToTrash(nc::utility::NativeFSManager &_nat_fsman) : m_NativeFSManager{_nat_fsman}
{
}

bool MoveToTrash::Predicate(PanelController *_target) const
{
    return CommonDeletePredicate(_target);
}

void MoveToTrash::Perform(PanelController *_target, id _sender) const
{
    auto items = _target.selectedEntriesOrFocusedEntry;

    if( !AllAreNative(items) ) {
        // instead of trying to silently reap files on VFS like FTP
        // (that means we'll erase it, not move to trash),
        // forward the request as a regular F8 delete
        Delete{m_NativeFSManager, false}.Perform(_target, _sender);
        return;
    }

    if( !TryTrash(items, m_NativeFSManager) ) {
        // if user called MoveToTrash by cmd+backspace but there's no trash on this volume:
        // show a dialog and ask him to delete a file permanently
        Delete{m_NativeFSManager, true}.Perform(_target, _sender);
        return;
    }

    const auto operation = std::make_shared<nc::ops::Deletion>(std::move(items), nc::ops::DeletionType::Trash);
    AddPanelRefreshEpilog(_target, *operation);
    [_target.mainWindowController enqueueOperation:operation];
}

context::MoveToTrash::MoveToTrash(const std::vector<VFSListingItem> &_items) : m_Items(_items)
{
    m_AllAreNative = AllAreNative(m_Items);
}

bool context::MoveToTrash::Predicate(PanelController * /*_target*/) const
{
    return m_AllAreNative;
}

void context::MoveToTrash::Perform(PanelController *_target, id /*_sender*/) const
{
    const auto operation = std::make_shared<nc::ops::Deletion>(m_Items, nc::ops::DeletionType::Trash);
    AddPanelRefreshEpilog(_target, *operation);
    [_target.mainWindowController enqueueOperation:operation];
}

context::DeletePermanently::DeletePermanently(const std::vector<VFSListingItem> &_items) : m_Items(_items)
{
    m_AllWriteable = std::ranges::all_of(m_Items, [](const auto &i) { return i.Host()->IsWritable(); });
}

bool context::DeletePermanently::Predicate(PanelController * /*_target*/) const
{
    return m_AllWriteable;
}

void context::DeletePermanently::Perform(PanelController *_target, id /*_sender*/) const
{
    const auto operation = std::make_shared<nc::ops::Deletion>(m_Items, nc::ops::DeletionType::Permanent);
    AddPanelRefreshEpilog(_target, *operation);
    [_target.mainWindowController enqueueOperation:operation];
}

static bool CommonDeletePredicate(PanelController *_target)
{
    auto i = _target.view.item;
    if( !i || !i.Host()->IsWritable() )
        return false;
    return !i.IsDotDot() || _target.data.Stats().selected_entries_amount > 0;
}

static bool AllAreNative(const std::vector<VFSListingItem> &_c)
{
    return std::ranges::all_of(_c, [&](auto &i) { return i.Host()->IsNativeFS(); });
}

static ankerl::unordered_dense::set<std::string> ExtractDirectories(const std::vector<VFSListingItem> &_c)
{
    ankerl::unordered_dense::set<std::string> directories;
    for( const auto &i : _c )
        directories.emplace(i.Directory());
    return directories;
}

static bool TryTrash(const std::vector<VFSListingItem> &_c, utility::NativeFSManager &_fsman)
{
    const auto directories = ExtractDirectories(_c);

    const bool all_have_trash = std::ranges::all_of(directories, [&](const std::string &dir) {
        if( auto vol = _fsman.VolumeFromPath(dir); vol && vol->interfaces.has_trash )
            return true;
        return false;
    });

    // if we already know that each volume have a trash folder - just say yes
    if( all_have_trash )
        return true;

    // otherwise, speculate a bit and try doing trash on locally-mounted volumes as well
    const bool all_are_local = std::ranges::all_of(directories, [&](const std::string &dir) {
        if( auto vol = _fsman.VolumeFromPath(dir); vol && vol->mount_flags.local )
            return true;
        return false;
    });
    return all_are_local;
}

static void AddPanelRefreshEpilog(PanelController *_target, nc::ops::Operation &_operation)
{
    __weak PanelController *weak_panel = _target;
    _operation.ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, [=] {
        dispatch_to_main_queue([=] {
            if( PanelController *const strong_pc = weak_panel )
                [strong_pc hintAboutFilesystemChange];
        });
    });
}

} // namespace nc::panel::actions
