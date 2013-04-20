//
//  PreferencesWindowController.m
//  Directories
//
//  Created by Pavel Dogurevich on 20.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PreferencesWindowController.h"

@interface PreferencesWindowController ()

@end

@implementation PreferencesWindowController
static PreferencesWindowController *SharedInstance = nil;

+ (void)ShowWindow
{
    if (!SharedInstance) SharedInstance = [[PreferencesWindowController alloc] init];
    
    if ([SharedInstance.window isVisible])
        [SharedInstance.window makeKeyAndOrderFront:nil];
    else
        [SharedInstance showWindow:nil];
}

- (id)init
{
    self = [super initWithWindowNibName:@"PreferencesWindowController"];
    if (self)
    {
    }
    
    return self;
}

- (void)windowWillClose:(NSNotification *)notification
{
    if (notification.object == self.window)
    {
        SharedInstance = nil;
    }
}

@end
