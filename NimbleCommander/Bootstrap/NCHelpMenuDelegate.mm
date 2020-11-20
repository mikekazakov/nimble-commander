// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NCHelpMenuDelegate.h"

@implementation NCHelpMenuDelegate

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    const auto debug_submenu_tag = 17'020;
    const auto menu_item = [menu itemWithTag:debug_submenu_tag];
    if( menu_item ) {
        const auto show_mask = NSEventModifierFlagOption;
        const bool do_hide = (NSEvent.modifierFlags & show_mask) == 0;
        menu_item.hidden = do_hide;
    }
}

@end
