//
//  AppDelegate.h
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "ApplicationSkins.h"

@class MainWindowController;
@class GenericConfigObjC;

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (IBAction)NewWindow:(id)sender;
- (MainWindowController*) AllocateNewMainWindow;
- (void) RemoveMainWindow:(MainWindowController*) _wnd;

/**
 * Runs a modal dialog window, which asks user if he wants to reset app settings.
 * Returns true if defaults were actually reset.
 */
- (bool) askToResetDefaults;

/** Returns all main windows currently present. */
@property (nonatomic, readonly) vector<MainWindowController*> mainWindowControllers;

/**
 * Equal to (AppDelegate*) ((NSApplication*)NSApp).delegate.
 */
+ (AppDelegate*) me;

/**
 * KVO-compatible property about current app skin.
 */
@property (nonatomic, readonly) ApplicationSkin skin;

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

/**
 * Support dir, ~/Library/Application Support/Nimble Commander.
 * Is in Containers for Sandboxes versions
 */
@property (nonatomic, readonly) const string& supportDirectory;

/**
 * By default this dir is ~/Library/Application Support/Files(Lite,Pro).
 * May change in the future.
 */
@property (nonatomic, readonly) const string& configDirectory;

/**
 * This dir is ~/Library/Application Support/Files(Lite,Pro)/State/.
 */
@property (nonatomic, readonly) const string& stateDirectory;

@property (nonatomic, readonly) GenericConfigObjC *config;

@end
