#include <VFS/Native.h>
#include "../Views/GoToFolderSheetController.h"
#include "../PanelController.h"
#include "GoToFolder.h"

namespace panel::actions {

bool GoToFolder::Predicate( PanelController *_target )
{
    return true;
}

bool GoToFolder::ValidateMenuItem( PanelController *_target, NSMenuItem *_item )
{
    return Predicate( _target );
}

void GoToFolder::Perform( PanelController *_target, id _sender )
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

        // TODO: check reachability from sandbox        
        
        [_target GoToDirWithContext:c];
    }];
}

};
