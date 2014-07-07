//
//  PreferencesWindowGeneralTab.m
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PreferencesWindowGeneralTab.h"
#import "SandboxManager.h"

@implementation PreferencesWindowGeneralTab

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    if(!configuration::is_sandboxed) {
        self.FSAccessResetButton.hidden = true;
        self.FSAccessLabel.hidden = true;
    }
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:@"pref_general_icon"];
}
-(NSString*)toolbarItemLabel{
    return @"General";
}

- (IBAction)ResetToDefaults:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Are you sure want to return to defaults?";
    alert.informativeText = @"This will erase all your custom settings.";
    [alert addButtonWithTitle:@"Ok"];
    [alert addButtonWithTitle:@"Cancel"];    
    [[alert.buttons objectAtIndex:0] setKeyEquivalent:@""];
    if([alert runModal] == NSAlertFirstButtonReturn)
        [NSUserDefaults.standardUserDefaults removePersistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
}

- (IBAction)OnFSAccessReset:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Are you sure want to reset granted file system access?";
    alert.informativeText = @"This will cause Files to ask you for access upon need.";
    [alert addButtonWithTitle:@"Ok"];
    [alert addButtonWithTitle:@"Cancel"];
    [[alert.buttons objectAtIndex:0] setKeyEquivalent:@""];
    if([alert runModal] == NSAlertFirstButtonReturn)
        SandboxManager::Instance().ResetBookmarks();
}

@end
