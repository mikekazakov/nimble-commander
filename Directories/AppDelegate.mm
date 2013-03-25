//
//  AppDelegate.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "AppDelegate.h"

#import "TestWindowController.h"

#include "DirRead.h"
#include "PanelData.h"
#include "MainWindowController.h"

@implementation AppDelegate
{
    MainWindowController *m_MainWindowController;
    TestWindowController *m_TestWindowController;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application

    // TODO: remove test window
    // fast switch between main window and test window
    if (true)
    {
        MainWindowController *mwc = [[MainWindowController alloc] init];
        [mwc showWindow:self];
        m_MainWindowController = mwc;
    }
    else
    {
        m_TestWindowController = [[TestWindowController alloc] init];
        [m_TestWindowController showWindow:self];
    }
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
