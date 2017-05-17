#include "GoToFolder.h"
#include <Habanero/CommonPaths.h>
#include <VFS/Native.h>
#include <VFS/PS.h>
#include <NimbleCommander/Core/SandboxManager.h>
#include "../Views/GoToFolderSheetController.h"
#include "../PanelController.h"
#include "../PanelData.h"
#include <NimbleCommander/States/FilePanels/PanelDataPersistency.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include "NavigateHistory.h"

namespace nc::panel::actions {

void GoToFolder::Perform( PanelController *_target, id _sender ) const
{
    GoToFolderSheetController *sheet = [GoToFolderSheetController new];
    sheet.panel = _target;
    [sheet showSheetWithParentWindow:_target.window handler:[=]{
        
        auto c = make_shared<DirectoryChangeRequest>();
        c->RequestedDirectory = [_target expandPath:sheet.requestedPath];
        c->VFS = _target.isUniform ?
            _target.vfs :
            VFSNativeHost::SharedHost();
        c->PerformAsynchronous = true;
        c->LoadingResultCallback = [=](int _code) {
            dispatch_to_main_queue( [=]{
                [sheet tellLoadingResult:_code];
            });
        };

        bool access_allowed = !c->VFS->IsNativeFS() ||
                                SandboxManager::EnsurePathAccess(c->RequestedDirectory);
        if( access_allowed )
            [_target GoToDirWithContext:c];
    }];
}

static void GoToNativeDir( const string& _path, PanelController *_target )
{
    if( SandboxManager::EnsurePathAccess(_path) )
        [_target GoToDir:_path vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

void GoToHomeFolder::Perform( PanelController *_target, id _sender ) const
{
    GoToNativeDir( CommonPaths::Home(), _target );
}

void GoToDocumentsFolder::Perform( PanelController *_target, id _sender ) const
{
    GoToNativeDir( CommonPaths::Documents(), _target );
}

void GoToDesktopFolder::Perform( PanelController *_target, id _sender ) const
{
    GoToNativeDir( CommonPaths::Desktop(), _target );
}

void GoToDownloadsFolder::Perform( PanelController *_target, id _sender ) const
{
    GoToNativeDir( CommonPaths::Downloads(), _target );
}

void GoToApplicationsFolder::Perform( PanelController *_target, id _sender ) const
{
   GoToNativeDir( CommonPaths::Applications(), _target );
}

void GoToUtilitiesFolder::Perform( PanelController *_target, id _sender ) const
{
   GoToNativeDir( CommonPaths::Utilities(), _target );
}

void GoToLibraryFolder::Perform( PanelController *_target, id _sender ) const
{
   GoToNativeDir( CommonPaths::Library(), _target );
}

void GoToRootFolder::Perform( PanelController *_target, id _sender ) const
{
   GoToNativeDir( CommonPaths::Root(), _target );
}

void GoToProcessesList::Perform( PanelController *_target, id _sender ) const
{
    [_target GoToDir:"/" vfs:VFSPSHost::GetSharedOrNew() select_entry:"" async:true];
}

void GoToFavoriteLocation::Perform( PanelController *_target, id _sender ) const
{
    if( auto menuitem = objc_cast<NSMenuItem>(_sender) )
        if( auto holder = objc_cast<AnyHolder>(menuitem.representedObject) )
            if( auto location = any_cast<PersistentLocation>(&holder.any) )
                [_target goToPersistentLocation:*location];
}

bool GoToEnclosingFolder::Predicate( PanelController *_target ) const
{
    static const auto root = "/"s;

    if( _target.isUniform ) {
        if( _target.data.Listing().Directory() != root )
            return true;
        
        return _target.vfs->Parent() != nullptr;
    }
    else
        return GoBack{}.Predicate(_target);
}

static bool SandboxAccessDenied( const VFSHost &_host, const string &_path )
{
    return _host.IsNativeFS() && !SandboxManager::EnsurePathAccess(_path);
}

void GoToEnclosingFolder::Perform( PanelController *_target, id _sender ) const
{
    if( _target.isUniform  ) {
        path cur = path(_target.data.DirectoryPathWithTrailingSlash());
        if( cur.empty() )
            return;
        
        const auto vfs = _target.vfs;
        
        if( cur == "/" ) {
            if( const auto parent_vfs = vfs->Parent() ) {
                path junct = vfs->JunctionPath();
                assert(!junct.empty());
                string dir = junct.parent_path().native();
                string sel_fn = junct.filename().native();
                
                if( SandboxAccessDenied(*parent_vfs, dir) )
                    return; // silently reap this command, since user refuses to grant an access
                
                [_target GoToDir:dir
                             vfs:parent_vfs
                    select_entry:sel_fn
               loadPreviousState:true
                           async:true];
            }
        }
        else {
            string dir = cur.parent_path().remove_filename().native();
            string sel_fn = cur.parent_path().filename().native();
            
            if( SandboxAccessDenied(*vfs, dir) )
                return; // silently reap this command, since user refuses to grant an access
            
            [_target GoToDir:dir
                         vfs:vfs
                select_entry:sel_fn
           loadPreviousState:true
                       async:true];
        }
    }
    else if( GoBack{}.Predicate(_target) ) {
        GoBack{}.Perform(_target, _sender);
    }
}

};
