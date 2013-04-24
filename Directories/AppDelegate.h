//
//  AppDelegate.h
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "PanelView.h"

@class MainWindowController;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowRestoration>

+ (void)initialize;

- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long) _ticket;

- (IBAction)NewWindow:(id)sender;
- (void) RemoveMainWindow:(MainWindowController*) _wnd;

- (IBAction)OnMenuSendFeedback:(id)sender;

@end
