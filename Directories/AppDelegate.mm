//
//  AppDelegate.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "AppDelegate.h"
#include "DirRead.h"
#include "PanelData.h"
#include "MainWindowController.h"

@implementation AppDelegate
{
    MainWindowController *m_MainWindowController;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application

    MainWindowController *mwc = [[MainWindowController alloc] init];
    [mwc showWindow:self];
    m_MainWindowController = mwc;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long) _ticket
{
    [m_MainWindowController FireDirectoryChanged:_dir ticket:_ticket];
}

@end
