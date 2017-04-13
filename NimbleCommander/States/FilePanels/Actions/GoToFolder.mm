#include <Habanero/CommonPaths.h>
#include <VFS/Native.h>
#include <VFS/PS.h>
#include <NimbleCommander/Core/SandboxManager.h>
#include "../Views/GoToFolderSheetController.h"
#include "../PanelController.h"
#include "GoToFolder.h"

namespace panel::actions {

void GoToFolder::Perform( PanelController *_target, id _sender ) const
{
    GoToFolderSheetController *sheet = [GoToFolderSheetController new];
    sheet.panel = _target;
    [sheet showSheetWithParentWindow:_target.window handler:[=]{
        
        auto c = make_shared<PanelControllerGoToDirContext>();
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

};
