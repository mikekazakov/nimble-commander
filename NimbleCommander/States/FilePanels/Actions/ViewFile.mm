// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ViewFile.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include <NimbleCommander/States/MainWindowController.h>

namespace nc::panel::actions {
    
bool ViewFile::Predicate( PanelController *_target ) const
{
    const auto item = _target.view.item;
    if( !item )
        return false;
    
    if( item.IsDir() )
        return false;
    
    return true;
}
    
void ViewFile::Perform( PanelController *_target, id ) const
{
    const auto item = _target.view.item;
    if( !item )
        return;
    
    if( item.IsDir() )
        return;

    [_target.mainWindowController requestViewerFor:item.Path()
                                                at:item.Host()];
}
    
}
