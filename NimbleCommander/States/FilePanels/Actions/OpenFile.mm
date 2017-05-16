#include "OpenFile.h"
#include "../NCPanelOpenWithMenuDelegate.h"
#include "../PanelController.h"
#include "../PanelView.h"
#include "../PanelData.h"
#include <VFS/VFS.h>

namespace nc::panel::actions {

static NCPanelOpenWithMenuDelegate *Delegate()
{
    static NCPanelOpenWithMenuDelegate *instance = [[NCPanelOpenWithMenuDelegate alloc] init];
    return instance;
}

static bool CommonPredicate( PanelController *_target )
{
    auto i = _target.view.item;
    if( !i )
        return false;
    
    return !i.IsDotDot() || _target.data.Stats().selected_entries_amount > 0;
}

bool OpenFileWithSubmenu::Predicate( PanelController *_target ) const
{
    return CommonPredicate(_target);
}

bool OpenFileWithSubmenu::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    if( !_item.hasSubmenu ) {
        NSMenu *menu = [[NSMenu alloc] init];
        menu.identifier = NCPanelOpenWithMenuDelegate.regularMenuIdentifier;
        menu.delegate = Delegate();
        [Delegate() addManagedMenu:menu];
        _item.submenu = menu;
    }
    
    Delegate().target = _target;

    return Predicate(_target);
}

bool AlwaysOpenFileWithSubmenu::Predicate( PanelController *_target ) const
{
    return CommonPredicate(_target);
}

bool AlwaysOpenFileWithSubmenu::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    if( !_item.hasSubmenu ) {
        NSMenu *menu = [[NSMenu alloc] init];
        menu.identifier = NCPanelOpenWithMenuDelegate.alwaysOpenWithMenuIdentifier;
        menu.delegate = Delegate();
        [Delegate() addManagedMenu:menu];
        _item.submenu = menu;
    }
    
    Delegate().target = _target;

    return Predicate(_target);
}

}
