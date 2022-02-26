// Copyright (C) 2016-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include "PreferencesWindowGeneralTab.h"
#include "PreferencesWindowPanelsTab.h"
#include "PreferencesWindowViewerTab.h"
#include "PreferencesWindowExternalEditorsTab.h"
#include "PreferencesWindowTerminalTab.h"
#include "PreferencesWindowHotkeysTab.h"
#include "PreferencesWindowToolsTab.h"
#include "PreferencesWindowThemesTab.h"
#include "Preferences.h"

static RHPreferencesWindowController *CreatePrefWindow()
{
    auto tools_storage = []() -> nc::panel::ExternalToolsStorage & { return NCAppDelegate.me.externalTools; };
    auto app_del = NCAppDelegate.me;
    auto &am = app_del.activationManager;
    auto tabs = @[
        [[PreferencesWindowGeneralTab alloc] initWithActivationManager:am],
        [[PreferencesWindowThemesTab alloc] initWithActivationManager:am],
        [PreferencesWindowPanelsTab new],
        [[PreferencesWindowViewerTab alloc] initWithHistory:app_del.internalViewerHistory
                                          activationManager:am],
        [[PreferencesWindowExternalEditorsTab alloc]
            initWithActivationManager:am
                       editorsStorage:app_del.externalEditorsStorage],
        [[PreferencesWindowTerminalTab alloc] initWithActivationManager:am],
        [[PreferencesWindowHotkeysTab alloc] initWithToolsStorage:tools_storage
                                                activationManager:am],
        [[PreferencesWindowToolsTab alloc] initWithToolsStorage:tools_storage
                                              activationManager:am]
    ];
    return [[RHPreferencesWindowController alloc] initWithViewControllers:tabs
                                                                 andTitle:@"Preferences"];
}

void ShowPreferencesWindow()
{
    static const auto preferences = CreatePrefWindow();
    [preferences showWindow:nil];
    GA().PostScreenView("Preferences Window");
}
