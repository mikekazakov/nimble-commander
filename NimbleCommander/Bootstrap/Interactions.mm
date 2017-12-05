// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Interactions.h"
#include "ActivationManager.h"
#include <Habanero/CommonPaths.h>
#include <NimbleCommander/Core/Alert.h>

namespace nc::bootstrap {

optional<string> AskUserForLicenseFile()
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.resolvesAliases = true;
    panel.canChooseDirectories = false;
    panel.canChooseFiles = true;
    panel.allowsMultipleSelection = false;
    panel.showsHiddenFiles = true;
    const auto extension = ActivationManager::LicenseFileExtension();
    panel.allowedFileTypes = @[ [NSString stringWithUTF8StdString:extension] ];
    panel.allowsOtherFileTypes = false;
    const auto downloads_path = [NSString stringWithUTF8StdString:CommonPaths::Downloads()];
    panel.directoryURL = [[NSURL alloc] initFileURLWithPath:downloads_path isDirectory:true];
    
    if( [panel runModal] == NSFileHandlingPanelOKButton )
        if(panel.URL != nil) {
            string path = panel.URL.path.fileSystemRepresentationSafe;
            return path;
        }
    return nullopt;
}

bool AskUserToResetDefaults()
{
    const auto msg =
        NSLocalizedString(@"Are you sure you want to reset settings to defaults?",
                          "Asking user for confirmation on erasing custom settings - message");
    const auto info =
        NSLocalizedString(@"This will erase all your custom settings.",
                          "Asking user for confirmation on erasing custom settings - informative text");

    
    Alert *alert = [[Alert alloc] init];
    alert.messageText = msg;
    alert.informativeText = info;
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    [alert.buttons objectAtIndex:0].keyEquivalent = @"";
    if( [alert runModal] == NSAlertFirstButtonReturn )
        return  true;
    return false;
}
    
bool AskUserToProvideUsageStatistics()
{
    const auto msg =
        NSLocalizedString(@"Please help us to improve the product",
                          "Asking user to provide anonymous usage information - message");
    const auto info =
        NSLocalizedString(@"Would you like to send anonymous usage statistics to the developer? None of your personal data would be collected.",
                          "Asking user to provide anonymous usage information - informative text");
    
    Alert *alert = [[Alert alloc] init];
    alert.messageText = msg;
    alert.informativeText = info;
    [alert addButtonWithTitle:NSLocalizedString(@"Send", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Don't send", "")];
    return [alert runModal] == NSAlertFirstButtonReturn;
}
    
}
