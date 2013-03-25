//
//  TestWindowController.h
//  Directories
//
//  Created by Pavel Dogurevich on 24.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TestWindowController : NSWindowController

- (IBAction)AddOperationButtonAction:(NSButton*)sender;

@property (weak) IBOutlet NSView *TempView;

@end
