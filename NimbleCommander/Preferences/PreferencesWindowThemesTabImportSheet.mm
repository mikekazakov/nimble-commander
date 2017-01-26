//
//  PreferencesWindowThemesTabImportSheet.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 1/26/17.
//  Copyright © 2017 Michael G. Kazakov. All rights reserved.
//

#import "PreferencesWindowThemesTabImportSheet.h"

@interface PreferencesWindowThemesTabImportSheet ()

@end

@implementation PreferencesWindowThemesTabImportSheet

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.overwriteCurrentTheme = true;
    self.importAsNewTheme = false;
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
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
