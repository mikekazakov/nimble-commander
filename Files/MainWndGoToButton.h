//
//  MainWndGoToButton.h
//  Directories
//
//  Created by Michael G. Kazakov on 11.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VFS.h"

@class MainWindowFilePanelState;

@interface MainWndGoToButton : NSPopUpButton<NSMenuDelegate>
@property (nonatomic, readonly) string path;
@property (nonatomic) __weak MainWindowFilePanelState *owner;
@property (nonatomic) bool isRight;

- (void) popUp;

@end
