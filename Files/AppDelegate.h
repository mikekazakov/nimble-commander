//
//  AppDelegate.h
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ApplicationSkins.h"

@class MainWindowController;

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (IBAction)NewWindow:(id)sender;
- (void) RemoveMainWindow:(MainWindowController*) _wnd;
- (MainWindowController*) AllocateNewMainWindow;

- (IBAction)OnMenuSendFeedback:(id)sender;

- (vector<MainWindowController*>) GetMainWindowControllers;


/**
 * Equal to (AppDelegate*) ((NSApplication*)NSApp).delegate.
 */
+ (AppDelegate*) me;

/**
 * KVO-compatible property about current app skin.
 */
@property (nonatomic, readonly) ApplicationSkin skin;

/**
 * Runs a modal dialog window, which asks user if he wants to reset app settings.
 * Returns true if defaults were actually reset.
 */
- (bool) askToResetDefaults;

/**
 * Will set a progress indicator at the bottom of app icon to a specified value in [0; 1].
 * Any value below 0.0 or above 1.0 will cause progress indicator to disappear.
 */
@property (nonatomic) double progress;

/**
 * Signals that applications runs in unit testing environment.
 * Thus it should strip it's windows etc.
 */
@property (nonatomic, readonly) bool isRunningTests;

/**
 * Initial working directory registered at application startup.
 */
@property (nonatomic, readonly) const string& startupCWD;

@end
