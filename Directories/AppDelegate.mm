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
#include <vector>

@implementation AppDelegate
{
    std::vector<MainWindowController *> m_MainWindows;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [self NewWindow:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long) _ticket
{
    for(auto i: m_MainWindows)
        [i FireDirectoryChanged:_dir ticket:_ticket];
}

- (IBAction)NewWindow:(id)sender
{
    MainWindowController *mwc = [[MainWindowController alloc] init];
    [mwc showWindow:self];
    m_MainWindows.push_back(mwc);
}

- (void) RemoveMainWindow:(MainWindowController*) _wnd
{
    for(auto i = m_MainWindows.begin(); i < m_MainWindows.end(); ++i)
        if(*i == _wnd)
        {
            m_MainWindows.erase(i);
            break;
        }
}

@end
