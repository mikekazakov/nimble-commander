//
//  AppStoreRatingsSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 15/02/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "AppStoreRatingsSheetController.h"
#import "Common.h"

@implementation AppStoreRatingsSheetController

- (id) init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self) {
    }
    return self;
}

- (NSModalResponse) runModal
{
    return [NSApplication.sharedApplication runModalForWindow:self.window];
}

- (IBAction)OnReview:(id)sender
{
    [self close];
    [NSApplication.sharedApplication stopModalWithCode:NSAlertFirstButtonReturn];
}

- (IBAction)OnRemind:(id)sender
{
    [self close];
    [NSApplication.sharedApplication stopModalWithCode:NSAlertSecondButtonReturn];
}

- (IBAction)OnNo:(id)sender
{
    [self close];    
    [NSApplication.sharedApplication stopModalWithCode:NSAlertThirdButtonReturn];
}

@end
