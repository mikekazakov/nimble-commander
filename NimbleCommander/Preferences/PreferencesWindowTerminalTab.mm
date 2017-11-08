// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontExtras.h>
#include "../Bootstrap/Config.h"
#include "../Bootstrap/ActivationManager.h"
#include "PreferencesWindowTerminalTab.h"

static const auto g_ConfigFont = "terminal.font";

// this stuff currently works only in one direction:
// config -> ObjectiveC property
// need to make it work bothways and move it to Config.mm after some using
class ConfigBinder
{
public:
    ConfigBinder( GenericConfig &_config, const char *_config_path, id _object, NSString *_object_key ):
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
        if( id v = [GenericConfigObjC valueForKeyPath:m_ConfigPath inConfig:&m_Config] )
            [m_Object setValue:v forKey:m_ObjectKey];
    }

    GenericConfig &m_Config;
    const char *m_ConfigPath;
    GenericConfig::ObservationTicket m_Ticket;
    
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
    unique_ptr<ConfigBinder> m_B1;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
        m_B1 = make_unique<ConfigBinder>( GlobalConfig(), "terminal.useDefaultLoginShell", self, @"usesDefaultLoginShell" );
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
    m_Font = [NSFont fontWithStringDescription:[NSString stringWithUTF8StdString:GlobalConfig().GetString(g_ConfigFont).value_or("")]];
    if(!m_Font) m_Font = [NSFont fontWithName:@"Menlo-Regular" size:13];

    [self updateFontVisibleName];
    [self.view layoutSubtreeIfNeeded];
}

- (NSToolbarItem *)toolbarItem
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:self.identifier];
    item.image = self.toolbarItemImage;
    item.label = self.toolbarItemLabel;
    item.enabled = ActivationManager::Instance().HasTerminal();
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
