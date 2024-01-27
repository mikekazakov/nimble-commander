// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowTerminalTab.h"
#include <Utility/FontExtras.h>
#include <Config/ObjCBridge.h>
#include "../Bootstrap/Config.h"
#include <Utility/StringExtras.h>
#include <Base/debug.h>

// this stuff currently works only in one direction:
// config -> ObjectiveC property
// need to make it work bothways and move it to Config.mm after some using
class ConfigBinder
{
public:
    ConfigBinder(nc::config::Config &_config, const char *_config_path, id _object, NSString *_object_key)
        : m_Config(_config), m_ConfigPath(_config_path),
          m_Ticket(_config.Observe(_config_path, [=] { ConfigChanged(); })), m_Object(_object), m_ObjectKey(_object_key)
    {
        ConfigChanged();
    }

    ~ConfigBinder() {}

private:
    void ConfigChanged()
    {
        auto bridge = [[NCConfigObjCBridge alloc] initWithConfig:m_Config];
        if( id v = [bridge valueForKeyPath:[NSString stringWithUTF8String:m_ConfigPath]] )
            [m_Object setValue:v forKey:m_ObjectKey];
    }

    nc::config::Config &m_Config;
    const char *m_ConfigPath;
    nc::config::Token m_Ticket;

    __weak id m_Object;
    NSString *m_ObjectKey;
};

@interface PreferencesWindowTerminalTab ()

@property(nonatomic) bool usesDefaultLoginShell;

@end

@implementation PreferencesWindowTerminalTab {
    NSFont *m_Font;
    std::unique_ptr<ConfigBinder> m_B1;
}

- (instancetype)init
{
    self = [super init];
    if( self ) {
        m_B1 = std::make_unique<ConfigBinder>(
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
    item.enabled = nc::base::AmISandboxed() == false;
    return item;
}

- (NSString *)identifier
{
    return NSStringFromClass(self.class);
}
- (NSImage *)toolbarItemImage
{
    return [NSImage imageNamed:@"PreferencesIcons_Terminal"];
}
- (NSString *)toolbarItemLabel
{
    return NSLocalizedStringFromTable(@"Terminal", @"Preferences", "General preferences tab title");
}

@end
