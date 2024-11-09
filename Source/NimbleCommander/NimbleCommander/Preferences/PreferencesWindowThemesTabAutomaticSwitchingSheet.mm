// Copyright (C) 2022-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PreferencesWindowThemesTabAutomaticSwitchingSheet.h"
#include <Utility/StringExtras.h>

@interface PreferencesWindowThemesTabAutomaticSwitchingSheet ()
@property(nonatomic, strong) IBOutlet NSPopUpButton *lightThemePopUp;
@property(nonatomic, strong) IBOutlet NSPopUpButton *darkThemePopUp;
@property(nonatomic) bool autoSwitchingEnabled;
@end

@implementation PreferencesWindowThemesTabAutomaticSwitchingSheet {
    std::vector<std::string> m_ThemeNames;
    nc::ThemesManager::AutoSwitchingSettings m_OrigSettings;
    nc::ThemesManager::AutoSwitchingSettings m_NewSettings;
}

@synthesize settings = m_NewSettings;
@synthesize lightThemePopUp;
@synthesize darkThemePopUp;
@synthesize autoSwitchingEnabled;

- (instancetype)init
{
    abort();
}

- (instancetype)initWithSwitchingSettings:(const nc::ThemesManager::AutoSwitchingSettings &)_autoswitching
                            andThemeNames:(std::span<const std::string>)_names
{
    self = [super init];
    if( self ) {
        m_ThemeNames.insert(m_ThemeNames.end(), _names.begin(), _names.end());
        m_OrigSettings = _autoswitching;
        self.autoSwitchingEnabled = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    for( auto &name : m_ThemeNames ) {
        auto ns_name = [NSString stringWithUTF8StdString:name];
        [self.lightThemePopUp addItemWithTitle:ns_name];
        [self.darkThemePopUp addItemWithTitle:ns_name];
    }

    self.autoSwitchingEnabled = m_OrigSettings.enabled;
    [self.lightThemePopUp selectItemWithTitle:[NSString stringWithUTF8StdString:m_OrigSettings.light]];
    [self.darkThemePopUp selectItemWithTitle:[NSString stringWithUTF8StdString:m_OrigSettings.dark]];
}

- (IBAction)onOK:(id)sender
{
    m_NewSettings.enabled = self.autoSwitchingEnabled;
    m_NewSettings.light =
        self.lightThemePopUp.indexOfSelectedItem >= 0 ? self.lightThemePopUp.titleOfSelectedItem.UTF8String : "";
    m_NewSettings.dark =
        self.darkThemePopUp.indexOfSelectedItem >= 0 ? self.darkThemePopUp.titleOfSelectedItem.UTF8String : "";

    [self endSheet:NSModalResponseOK];
}

- (IBAction)onCancel:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

@end
