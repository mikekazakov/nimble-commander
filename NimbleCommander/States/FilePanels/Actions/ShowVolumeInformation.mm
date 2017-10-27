// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/GeneralUI/DetailedVolumeInformationSheetController.h>
#include "../PanelController.h"
#include "ShowVolumeInformation.h"
#include "../PanelView.h"
#include <VFS/VFS.h>

namespace nc::panel::actions {

bool ShowVolumeInformation::Predicate( PanelController *_target ) const
{
    return _target.isUniform && _target.vfs->IsNativeFS();
}

void ShowVolumeInformation::Perform( PanelController *_target, id _sender ) const
{
    string path;
    if( auto i = _target.view.item ) {
        if( !i.Host()->IsNativeFS() )
            return;
        if( !i.IsDotDot() )
            path = i.Path();
        else
            path = i.Directory();
    }
    else if( _target.isUniform ) {
        if( !_target.vfs->IsNativeFS() )
            return;
        path = _target.currentDirectoryPath;
    }
    else
        return;
    
    auto sheet = [DetailedVolumeInformationSheetController new];
    [sheet showSheetForWindow:_target.window withPath:path];
}

};
