//
//  AppStoreRatingsSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 15/02/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "AppStoreRatingsSheetController.h"
#include "GoogleAnalytics.h"

@interface AppStoreRatingsSheetController()

- (IBAction)OnReview:(id)sender;
- (IBAction)OnRemind:(id)sender;
- (IBAction)OnNo:(id)sender;

@end

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
    GoogleAnalytics::Instance().PostScreenView("App Store Ratings");
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
