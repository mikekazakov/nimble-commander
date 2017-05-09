#include <VFS/XAttr.h>
#include <NimbleCommander/Core/Alert.h>
#include "../PanelController.h"
#include "OpenXAttr.h"
#include "../PanelView.h"

namespace panel::actions {

bool OpenXAttr::Predicate( PanelController *_target ) const
{
    auto i = _target.view.item;
    return i && i.Host()->IsNativeFS();
}

void OpenXAttr::Perform( PanelController *_target, id _sender ) const
{
    if( !Predicate(_target) )
        return;
    
    try {
        auto host = make_shared<VFSXAttrHost>( _target.view.item.Path(), _target.view.item.Host() );
        auto context = make_shared<PanelControllerGoToDirContext>();
        context->VFS = host;
        context->RequestedDirectory = "/";
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
