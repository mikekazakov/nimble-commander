// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#import "PreferencesWindowThemesTabImportSheet.h"

@implementation PreferencesWindowThemesTabImportSheet
@synthesize overwriteCurrentTheme;
@synthesize importAsNewTheme;
@synthesize importAsName;

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.overwriteCurrentTheme = true;
    self.importAsNewTheme = false;
}

- (IBAction)onImport:(id) [[maybe_unused]] _sender
{
    [self endSheet:NSModalResponseOK];
}

- (IBAction)onCancel:(id) [[maybe_unused]] _sender
{
    [self endSheet:NSModalResponseCancel];
}

- (void)setImportAsNewTheme:(bool)_importAsNewTheme
{
    if( importAsNewTheme != _importAsNewTheme ) {
        [self willChangeValueForKey:@"importAsNewTheme"];
        importAsNewTheme = _importAsNewTheme;
        [self didChangeValueForKey:@"importAsNewTheme"];
        self.overwriteCurrentTheme = false;
    }
}

- (void)setOverwriteCurrentTheme:(bool)_overwriteCurrentTheme
{
    if( overwriteCurrentTheme != _overwriteCurrentTheme ) {
        [self willChangeValueForKey:@"overwriteCurrentTheme"];
        overwriteCurrentTheme = _overwriteCurrentTheme;
        [self didChangeValueForKey:@"overwriteCurrentTheme"];
        self.importAsNewTheme = false;
    }
}

@end
