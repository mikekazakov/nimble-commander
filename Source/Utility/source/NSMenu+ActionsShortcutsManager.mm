// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/NSMenu+ActionsShortcutsManager.h>
#include <Utility/ActionsShortcutsManager.h>

@implementation NSMenu (ActionsShortcutsManager)

- (void)nc_setMenuItemShortcutsWithActionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_asm
{
    NSArray *const array = self.itemArray;
    for( NSMenuItem *i : array ) {
        if( i.submenu != nil ) {
            [i.submenu nc_setMenuItemShortcutsWithActionsShortcutsManager:_asm];
            continue;
        }

        const int tag = static_cast<int>(i.tag);
        if( const auto shortcuts = _asm.ShortcutsFromTag(tag) ) {
            [i nc_setKeyEquivalentWithShortcut:shortcuts->empty() ? nc::utility::ActionShortcut{} : shortcuts->front()];
        }
    }
}

@end
