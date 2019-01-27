// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
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

void ShowPreferencesWindow()
{
    static const auto preferences = [=]{
        auto tools_storage = [=]()->ExternalToolsStorage&{
            return NCAppDelegate.me.externalTools;
        };
        auto tabs = @[[PreferencesWindowGeneralTab new],
                      [PreferencesWindowThemesTab new],
                      [PreferencesWindowPanelsTab new],
                      [[PreferencesWindowViewerTab alloc] initWithHistory:NCAppDelegate.me.internalViewerHistory],
                      [PreferencesWindowExternalEditorsTab new],
                      [PreferencesWindowTerminalTab new],
                      [[PreferencesWindowHotkeysTab alloc] initWithToolsStorage:tools_storage],
                      [[PreferencesWindowToolsTab alloc] initWithToolsStorage:tools_storage]];
        return [[RHPreferencesWindowController alloc] initWithViewControllers:tabs andTitle:@"Preferences"];
    }();
    
    [preferences showWindow:nil];
    GA().PostScreenView("Preferences Window");
}
