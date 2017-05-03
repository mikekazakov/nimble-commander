#include "Delete.h"
#include "../PanelController.h"
#include "../MainWindowFilePanelState.h"
#include <NimbleCommander/Operations/Delete/FileDeletionSheetController.h>
#include <Utility/NativeFSManager.h>
#include <Habanero/algo.h>

namespace panel::actions {

static bool CommonDeletePredicate( PanelController *_target );
static bool AllAreNative(const vector<VFSListingItem>& _c);
static unordered_set<string> ExtractDirectories(const vector<VFSListingItem>& _c);
static bool AllHaveTrash(const vector<VFSListingItem>& _c);
static void AddPanelRefreshEpilogIfNeeded( PanelController *_target, Operation* _operation );

Delete::Delete( bool _permanently ):
    m_Permanently(_permanently)
{
}

bool Delete::Predicate( PanelController *_target ) const
{
    return CommonDeletePredicate(_target);
}

void Delete::Perform( PanelController *_target, id _sender ) const
{
    auto items = to_shared_ptr(_target.selectedEntriesOrFocusedEntry);
    if( items->empty() )
        return;
    
    const auto sheet = [[FileDeletionSheetController alloc] initWithItems:items];
    if( AllAreNative(*items) ) {
        const auto all_have_trash = AllHaveTrash(*items);
        sheet.allowMoveToTrash = all_have_trash;
        sheet.defaultType = m_Permanently ?
            FileDeletionOperationType::Delete :
            (all_have_trash ?
                FileDeletionOperationType::MoveToTrash :
                FileDeletionOperationType::Delete);
    }
    else {
        sheet.allowMoveToTrash = false;
        sheet.defaultType = FileDeletionOperationType::Delete;
    }

    auto sheet_handler = ^(NSModalResponse returnCode) {
        if( returnCode == NSModalResponseOK ){
            const auto operation = [[FileDeletionOperation alloc] initWithFiles:move(*items)
                                                                           type:sheet.resultType];
            AddPanelRefreshEpilogIfNeeded(_target, operation);
            [_target.state AddOperation:operation];
        }
    };
    
    [sheet beginSheetForWindow:_target.window completionHandler:sheet_handler];
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
    
    const auto operation = [[FileDeletionOperation alloc]
        initWithFiles:move(items)
                 type:FileDeletionOperationType::MoveToTrash];
    AddPanelRefreshEpilogIfNeeded(_target, operation);
    [_target.state AddOperation:operation];
}

context::MoveToTrash::MoveToTrash(const vector<VFSListingItem> &_items):
    m_Items(_items)
{
    m_AllAreNative = AllAreNative(m_Items);
}

bool context::MoveToTrash::Predicate( PanelController *_target ) const
{
    return m_AllAreNative;
}

void context::MoveToTrash::Perform( PanelController *_target, id _sender ) const
{
    const auto operation = [[FileDeletionOperation alloc]
                            initWithFiles:m_Items
                            type:FileDeletionOperationType::MoveToTrash];
    AddPanelRefreshEpilogIfNeeded(_target, operation);
    [_target.state AddOperation:operation];
}

context::DeletePermanently::DeletePermanently(const vector<VFSListingItem> &_items):
    m_Items(_items)
{
    m_AllWriteable = all_of(begin(m_Items), end(m_Items), [](const auto &i){
        return i.Host()->IsWritable();
    });
}

bool context::DeletePermanently::Predicate( PanelController *_target ) const
{
    return m_AllWriteable;
}

void context::DeletePermanently::Perform( PanelController *_target, id _sender ) const
{
    const auto operation = [[FileDeletionOperation alloc]
                            initWithFiles:m_Items
                            type:FileDeletionOperationType::Delete];
    AddPanelRefreshEpilogIfNeeded(_target, operation);
    [_target.state AddOperation:operation];
}

static bool CommonDeletePredicate( PanelController *_target )
{
    auto i = _target.view.item;
    if( !i || !i.Host()->IsWritable() )
        return false;
    return !i.IsDotDot() || _target.data.Stats().selected_entries_amount > 0;
}

static bool AllAreNative(const vector<VFSListingItem>& _c)
{
    return all_of(begin(_c), end(_c), [&](auto &i){
        return i.Host()->IsNativeFS();
    });
}

static unordered_set<string> ExtractDirectories(const vector<VFSListingItem>& _c)
{
    unordered_set<string> directories;
    for(const auto &i: _c)
        directories.emplace( i.Directory() );
    return directories;
}

static bool AllHaveTrash(const vector<VFSListingItem>& _c)
{
    const auto directories = ExtractDirectories(_c);
    return all_of(begin(directories), end(directories), [](auto &i){
        if( auto vol = NativeFSManager::Instance().VolumeFromPath(i) )
            if( vol->interfaces.has_trash )
                return true;
        return false;
    });
}

static void AddPanelRefreshEpilogIfNeeded( PanelController *_target, Operation* _operation )
{
    if( !_target.receivesUpdateNotifications ) {
        __weak PanelController *weak_panel = _target;
        [_operation AddOnFinishHandler:[=]{
            dispatch_to_main_queue( [=]{
                [(PanelController*)weak_panel refreshPanel];
            });
        }];
    }
}

}
