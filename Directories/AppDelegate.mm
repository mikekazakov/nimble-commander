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
#import "OperationProgressValueTransformer.h"

#include <vector>

@implementation AppDelegate
{
    std::vector<MainWindowController *> m_MainWindows;
}

+ (void)initialize
{
    NSString *defaults_file = [[NSBundle mainBundle]
                               pathForResource:@"Defaults" ofType:@"plist"];
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaults_file];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [NSValueTransformer setValueTransformer:[[OperationProgressValueTransformer alloc] init]
                                    forName:@"OperationProgressValueTransformer"];
    
    if(m_MainWindows.empty())
        [self AllocateNewMainWindow]; // if there's no restored windows - we'll create a freshly new one
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

- (MainWindowController*)AllocateNewMainWindow
{
    MainWindowController *mwc = [[MainWindowController alloc] init];
    mwc.window.restorable = YES;
    mwc.window.restorationClass = self.class;
    mwc.window.identifier = @"mainwindow";
    
    [mwc showWindow:self];
    m_MainWindows.push_back(mwc);
    return mwc;
}

- (IBAction)NewWindow:(id)sender
{
    [self AllocateNewMainWindow];
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    NSWindow *window = nil;
    if ([identifier isEqualToString:@"mainwindow"])
    {
        AppDelegate *app = [NSApp delegate];
        window = [[app AllocateNewMainWindow] window];
    }
    completionHandler(window, nil);
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
