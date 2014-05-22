//
//  MainWndGoToButton.h
//  Directories
//
//  Created by Michael G. Kazakov on 11.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MainWindowFilePanelState;

@interface MainWndGoToButton : NSPopUpButton<NSMenuDelegate>

- (NSString*) path;
- (void) SetCurrentPath: (const char*)_path;
- (void) SetOwner:(MainWindowFilePanelState*) _owner;
- (void) SetAnchorPoint: (NSPoint)_point IsRight:(bool) _is_right; // screen coordinates

@end
