// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowTerminalTab.h"
#include <Utility/FontExtras.h>
#include <Config/ObjCBridge.h>
#include "../Bootstrap/Config.h"
#include "../Bootstrap/ActivationManager.h"
#include <Utility/StringExtras.h>

static const auto g_ConfigFont = "terminal.font";

// this stuff currently works only in one direction:
// config -> ObjectiveC property
// need to make it work bothways and move it to Config.mm after some using
class ConfigBinder
{
public:
    ConfigBinder( nc::config::Config &_config, const char *_config_path, id _object, NSString *_object_key ):
        m_Config(_config),
        m_Object(_object),
        m_ConfigPath(_config_path),
        m_ObjectKey(_object_key),
        m_Ticket( _config.Observe(_config_path, [=]{ConfigChanged();}) )
    {
        ConfigChanged();
    }
    
    ~ConfigBinder()
    {
    }
    
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


@interface PreferencesWindowTerminalTab()

@property (nonatomic) IBOutlet NSTextField *fontVisibleName;

@property (nonatomic) bool usesDefaultLoginShell;

@end

@implementation PreferencesWindowTerminalTab
{
    NSFont *m_Font;
    std::unique_ptr<ConfigBinder> m_B1;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
        m_B1 = std::make_unique<ConfigBinder>( GlobalConfig(), "terminal.useDefaultLoginShell", self, @"usesDefaultLoginShell" );
    }
    return self;
}

- (void) dealloc
{
    m_B1.reset();
}

- (void)loadView
{
    [super loadView];
    m_Font = [NSFont fontWithStringDescription:[NSString stringWithUTF8StdString:GlobalConfig().GetString(g_ConfigFont)]];
    if(!m_Font) m_Font = [NSFont fontWithName:@"Menlo-Regular" size:13];

    [self updateFontVisibleName];
    [self.view layoutSubtreeIfNeeded];
}

- (NSToolbarItem *)toolbarItem
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:self.identifier];
    item.image = self.toolbarItemImage;
    item.label = self.toolbarItemLabel;
    item.enabled = nc::bootstrap::ActivationManager::Instance().HasTerminal();
    return item;
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:@"PreferencesIcons_Terminal"];
}
-(NSString*)toolbarItemLabel{
    return NSLocalizedStringFromTable(@"Terminal",
                                      @"Preferences",
                                      "General preferences tab title");
}

- (void) updateFontVisibleName
{
    self.fontVisibleName.stringValue = [NSString stringWithFormat:@"%@ %.0f pt.", m_Font.displayName, m_Font.pointSize];
}

- (IBAction)OnSetFont:(id)sender
{
    NSFontManager * fontManager = [NSFontManager sharedFontManager];
    fontManager.target = self;
    fontManager.action = @selector(changeFont:);
    [fontManager setSelectedFont:m_Font isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (void)changeFont:(id)sender
{
    m_Font = [sender convertFont:m_Font];
    GlobalConfig().Set(g_ConfigFont, m_Font.toStringDescription.UTF8String);
    [self updateFontVisibleName];
}

@end
