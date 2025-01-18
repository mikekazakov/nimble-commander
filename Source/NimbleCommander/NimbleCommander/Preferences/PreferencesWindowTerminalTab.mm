// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowTerminalTab.h"
#include <Utility/FontExtras.h>
#include <Config/ObjCBridge.h>
#include "../Bootstrap/Config.h"
#include <Utility/StringExtras.h>
#include <Base/debug.h>
#include "ConfigBinder.h"

@interface PreferencesWindowTerminalTab ()

@property(nonatomic) bool usesDefaultLoginShell;

@end

@implementation PreferencesWindowTerminalTab {
    NSFont *m_Font;
    std::unique_ptr<nc::ConfigBinder> m_B1;
}
@synthesize usesDefaultLoginShell;

- (instancetype)init
{
    self = [super init];
    if( self ) {
        m_B1 = std::make_unique<nc::ConfigBinder>(
            GlobalConfig(), "terminal.useDefaultLoginShell", self, @"usesDefaultLoginShell");
    }
    return self;
}

- (void)dealloc
{
    m_B1.reset();
}

- (void)loadView
{
    [super loadView];
    [self.view layoutSubtreeIfNeeded];
}

- (NSToolbarItem *)toolbarItem
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:self.identifier];
    item.image = self.toolbarItemImage;
    item.label = self.toolbarItemLabel;
    item.enabled = !nc::base::AmISandboxed();
    return item;
}

- (NSString *)identifier
{
    return NSStringFromClass(self.class);
}

- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"preferences.toolbar.terminal"];
}

- (NSString *)toolbarItemLabel
{
    return NSLocalizedStringFromTable(@"Terminal", @"Preferences", "General preferences tab title");
}

@end
