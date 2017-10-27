// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import "PreferencesWindowThemesTabImportSheet.h"

@interface PreferencesWindowThemesTabImportSheet ()

@end

@implementation PreferencesWindowThemesTabImportSheet

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.overwriteCurrentTheme = true;
    self.importAsNewTheme = false;
}

- (IBAction)onImport:(id)sender
{
    [self endSheet:NSModalResponseOK];
}

- (IBAction)onCancel:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (void) setImportAsNewTheme:(bool)importAsNewTheme
{
    if( _importAsNewTheme != importAsNewTheme ) {
        [self willChangeValueForKey:@"importAsNewTheme"];
        _importAsNewTheme = importAsNewTheme;
        [self didChangeValueForKey:@"importAsNewTheme"];
        self.overwriteCurrentTheme = false;
    }
}

- (void) setOverwriteCurrentTheme:(bool)overwriteCurrentTheme
{
    if( _overwriteCurrentTheme != overwriteCurrentTheme ) {
        [self willChangeValueForKey:@"overwriteCurrentTheme"];
        _overwriteCurrentTheme = overwriteCurrentTheme;
        [self didChangeValueForKey:@"overwriteCurrentTheme"];
        self.importAsNewTheme = false;
    }
}

@end
