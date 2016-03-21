//
//  PreferencesWindowGeneralTab.m
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "PreferencesWindowGeneralTab.h"
#include "SandboxManager.h"
#include "AppDelegate.h"
#include "ActivationManager.h"

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
    if( !ActivationManager::Instance().Sandboxed() ) {
        self.FSAccessResetButton.hidden = true;
        self.FSAccessLabel.hidden = true;
    }
    [self.view layoutSubtreeIfNeeded];    
}

-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:@"pref_general_icon"];
}
-(NSString*)toolbarItemLabel{
    return NSLocalizedStringFromTable(@"General",
                                      @"Preferences",
                                      "General preferences tab title");
}

- (IBAction)ResetToDefaults:(id)sender
{
    [(AppDelegate*)[NSApplication sharedApplication].delegate askToResetDefaults];
}

- (IBAction)OnFSAccessReset:(id)sender
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedStringFromTable(@"Are you sure want to reset granted filesystem access?",
                                                   @"Preferences",
                                                   "Message text asking if user really wants to reset current file system access");
    alert.informativeText = NSLocalizedStringFromTable(@"This will cause Files to ask you for access upon need.",
                                                       @"Preferences",
                                                       "Informative text saying that Files will ask for filesystem access when need it");
    [alert addButtonWithTitle:NSLocalizedString(@"OK","")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel","")];
    [[alert.buttons objectAtIndex:0] setKeyEquivalent:@""];
    if([alert runModal] == NSAlertFirstButtonReturn)
        SandboxManager::Instance().ResetBookmarks();
}

@end
