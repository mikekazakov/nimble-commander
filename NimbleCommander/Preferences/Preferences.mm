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
            return AppDelegate.me.externalTools;
        };
        auto tabs = @[[PreferencesWindowGeneralTab new],
                      [PreferencesWindowThemesTab new],
                      [PreferencesWindowPanelsTab new],
                      [PreferencesWindowViewerTab new],
                      [PreferencesWindowExternalEditorsTab new],
                      [PreferencesWindowTerminalTab new],
                      [[PreferencesWindowHotkeysTab alloc] initWithToolsStorage:tools_storage],
                      [[PreferencesWindowToolsTab alloc] initWithToolsStorage:tools_storage]];
        return [[RHPreferencesWindowController alloc] initWithViewControllers:tabs andTitle:@"Preferences"];
    }();
    
    [preferences showWindow:nil];
    GoogleAnalytics::Instance().PostScreenView("Preferences Window");
}
