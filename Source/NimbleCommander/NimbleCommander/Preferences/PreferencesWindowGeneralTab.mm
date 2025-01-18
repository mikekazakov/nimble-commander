// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowGeneralTab.h"
#include "../Core/SandboxManager.h"
#include "../Bootstrap/AppDelegate.h"
#include <Base/dispatch_cpp.h>
#include <Base/debug.h>

using namespace std::literals;

@interface PreferencesWindowGeneralTab ()

@property(nonatomic) IBOutlet NSButton *FSAccessResetButton;
@property(nonatomic) IBOutlet NSTextField *FSAccessLabel;

@end

@implementation PreferencesWindowGeneralTab
@synthesize FSAccessResetButton;
@synthesize FSAccessLabel;

- (void)loadView
{
    [super loadView];
    if( !nc::base::AmISandboxed() ) {
        self.FSAccessResetButton.enabled = false;
    }
    [self.view layoutSubtreeIfNeeded];
}

- (NSString *)identifier
{
    return NSStringFromClass(self.class);
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"preferences.toolbar.general"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedStringFromTable(@"General", @"Preferences", "General preferences tab title");
}

- (IBAction)ResetToDefaults:(id) [[maybe_unused]] _sender
{
    [NCAppDelegate.me askToResetDefaults];
}

- (IBAction)OnFSAccessReset:(id) [[maybe_unused]] _sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText =
        NSLocalizedStringFromTable(@"Are you sure you want to reset granted filesystem access?",
                                   @"Preferences",
                                   "Message text asking if user really wants to reset current file system access");
    alert.informativeText = NSLocalizedStringFromTable(
        @"This will cause Nimble Commander to ask you for access when necessary.",
        @"Preferences",
        "Informative text saying that Nimble Commander will ask for filesystem access when need "
        "it");
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    [[alert.buttons objectAtIndex:0] setKeyEquivalent:@""];
    if( [alert runModal] == NSAlertFirstButtonReturn )
        SandboxManager::Instance().ResetBookmarks();
}

@end
