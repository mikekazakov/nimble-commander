// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

namespace nc::utility {
class ActionsShortcutsManager;
}

@interface NSMenu (ActionsShortcutsManager)

- (void)nc_setMenuItemShortcutsWithActionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_asm;

@end
