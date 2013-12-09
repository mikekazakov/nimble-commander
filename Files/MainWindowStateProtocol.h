//
//  MainWindowStateProtocol.h
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ApplicationSkins.h"


@class MainWindowController;

@protocol MainWindowStateProtocol <NSObject>

- (NSView*) ContentView;

@optional
- (void) Assigned;
- (void) Resigned;

- (void)DidBecomeKeyWindow;
- (void)WindowDidResize;
- (void)WindowWillClose;
- (void)WindowWillBeginSheet;
- (void)WindowDidEndSheet;
- (bool)WindowShouldClose:(MainWindowController*)sender;
- (void)SkinSettingsChanged;
- (void)ApplySkin:(ApplicationSkin)_skin;
- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect;
- (void)OnApplicationWillTerminate;

@end
