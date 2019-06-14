// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
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

- (IBAction)onImport:(id)[[maybe_unused]]_sender
{
    [self endSheet:NSModalResponseOK];
}

- (IBAction)onCancel:(id)[[maybe_unused]]_sender
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
