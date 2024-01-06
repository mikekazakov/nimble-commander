// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "OpenXAttr.h"
#include <VFS/XAttr.h>
#include <NimbleCommander/Core/Alert.h>
#include "../PanelController.h"
#include "../PanelView.h"

namespace nc::panel::actions {

bool OpenXAttr::Predicate( PanelController *_target ) const
{
    auto i = _target.view.item;
    return i && i.Host()->IsNativeFS();
}

void OpenXAttr::Perform( PanelController *_target, id ) const
{
    if( !Predicate(_target) )
        return;
    
    try {
        auto host = std::make_shared<vfs::XAttrHost>(_target.view.item.Path(),
                                                     _target.view.item.Host() );
        auto context = std::make_shared<DirectoryChangeRequest>();
        context->VFS = host;
        context->RequestedDirectory = "/";
        context->InitiatedByUser = true;
        [_target GoToDirWithContext:context];
    } catch (const VFSErrorException &e) {
        Alert *alert = [[Alert alloc] init];
        alert.messageText = NSLocalizedString(@"Failed to open extended attributes",
                                               "Alert message text when failed to open xattr vfs");
        alert.informativeText = VFSError::ToNSError(e.code()).localizedDescription;
        [alert runModal];
    }
}

};
