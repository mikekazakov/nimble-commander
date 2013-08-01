//
//  PreferencesWindowGeneralTab.m
//  Files
//
//  Created by Michael G. Kazakov on 13.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PreferencesWindowGeneralTab.h"

@interface PreferencesWindowGeneralTab ()

@end

@implementation PreferencesWindowGeneralTab

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}


-(NSString*)identifier{
    return NSStringFromClass(self.class);
}
-(NSImage*)toolbarItemImage{
    return [NSImage imageNamed:NSImageNamePreferencesGeneral];
}
-(NSString*)toolbarItemLabel{
    return @"General";
}

- (IBAction)ResetToDefaults:(id)sender
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Are you sure want to return to defaults?"
                                      defaultButton:@"Ok"
                                    alternateButton:@"Cancel"
                                        otherButton:nil
                          informativeTextWithFormat:@"This will erase all your custom settings."];
    [[[alert buttons] objectAtIndex:0] setKeyEquivalent:@""];
    if([alert runModal] == NSAlertDefaultReturn)
    {
        NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    }
}
@end
