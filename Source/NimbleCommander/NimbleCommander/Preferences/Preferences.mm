// Copyright (C) 2016-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include "PreferencesWindowGeneralTab.h"
#include "PreferencesWindowPanelsTab.h"
#include "PreferencesWindowViewerTab.h"
#include "PreferencesWindowExternalEditorsTab.h"
#include "PreferencesWindowTerminalTab.h"
#include "PreferencesWindowHotkeysTab.h"
#include "PreferencesWindowToolsTab.h"
#include "PreferencesWindowThemesTab.h"
#include "Preferences.h"

static PreferencesWindowController *CreatePrefWindow()
{
    auto tools_storage = []() -> nc::panel::ExternalToolsStorage & { return NCAppDelegate.me.externalTools; };
    auto app_del = NCAppDelegate.me;
    auto tabs = @[
        [PreferencesWindowGeneralTab new],
        [PreferencesWindowThemesTab new],
        [PreferencesWindowPanelsTab new],
        [[PreferencesWindowViewerTab alloc] initWithHistory:app_del.internalViewerHistory],
        [[PreferencesWindowExternalEditorsTab alloc] initWithEditorsStorage:app_del.externalEditorsStorage],
        [PreferencesWindowTerminalTab new],
        [[PreferencesWindowHotkeysTab alloc] initWithToolsStorage:tools_storage
                                          actionsShortcutsManager:app_del.actionsShortcutsManager],
        [[PreferencesWindowToolsTab alloc] initWithToolsStorage:tools_storage]
    ];
    return [[PreferencesWindowController alloc] initWithControllers:tabs title:@"Preferences"];
}

void ShowPreferencesWindow()
{
    static const auto preferences = CreatePrefWindow();
    [preferences showWindow:nil];
}
