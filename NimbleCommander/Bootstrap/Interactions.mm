// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Interactions.h"
#include "ActivationManager.h"
#include <Habanero/CommonPaths.h>
#include <NimbleCommander/Core/Alert.h>
#include <Utility/StringExtras.h>

namespace nc::bootstrap {

std::optional<std::string> AskUserForLicenseFile()
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.resolvesAliases = true;
    panel.canChooseDirectories = false;
    panel.canChooseFiles = true;
    panel.allowsMultipleSelection = false;
    panel.showsHiddenFiles = true;
    const auto extension = bootstrap::ActivationManager::LicenseFileExtension();
    panel.allowedFileTypes = @[ [NSString stringWithUTF8StdString:extension] ];
    panel.allowsOtherFileTypes = false;
    const auto downloads_path = [NSString stringWithUTF8StdString:CommonPaths::Downloads()];
    panel.directoryURL = [[NSURL alloc] initFileURLWithPath:downloads_path isDirectory:true];
    panel.message = NSLocalizedString(@"Please select your license file (.nimblecommanderlicense)", "");
    if( [panel runModal] == NSFileHandlingPanelOKButton )
        if(panel.URL != nil) {
            std::string path = panel.URL.path.fileSystemRepresentationSafe;
            return path;
        }
    return std::nullopt;
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
    
bool AskToExitWithRunningOperations()
{
    const auto msg =
        NSLocalizedString(@"The application has running operations. Do you want to stop all operations and quit?",
                          "Asking user for quitting app with activity");
    
    Alert *alert = [[Alert alloc] init];
    alert.messageText = msg;
    [alert addButtonWithTitle:NSLocalizedString(@"Stop and Quit", "Asking user for quitting app with activity - confirmation")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    NSInteger result = [alert runModal];
    
    return result == NSAlertFirstButtonReturn;
}
    
void ThankUserForBuyingALicense()
{
    const auto msg =
        NSLocalizedString(@"__THANKS_FOR_REGISTER_MESSAGE",
                          "Message to thank user for buying");
    const auto info =
        NSLocalizedString(@"__THANKS_FOR_REGISTER_INFORMATIVE",
                          "Informative text to thank user for buying");
    
    Alert *alert = [[Alert alloc] init];
    alert.icon = [NSImage imageNamed:@"checked_icon"];
    alert.messageText = msg;
    alert.informativeText = info;
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert runModal];
}

void WarnAboutFailingToAccessPriviledgedHelper()
{
    const auto msg =
        NSLocalizedString(@"Failed to access the privileged helper.",
                          "Information that toggling admin mode on has failed");
    
    Alert *alert = [[Alert alloc] init];
    alert.messageText = msg;
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert runModal];
}
    
}
