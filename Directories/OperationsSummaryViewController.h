//
//  OperationsSummaryViewController.h
//  Directories
//
//  Created by Pavel Dogurevich on 23.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "OperationsController.h"

@interface OperationsSummaryViewController : NSViewController

@property (weak) IBOutlet NSTextField *TopOperationCaption;
@property (weak) IBOutlet NSProgressIndicator *TopOperationProgress;
@property (weak) IBOutlet NSButton *OperationsCountButton;
@property Operation *TopOperation;

- (id)initWthController:(OperationsController *)_controller;

- (void)AddViewTo:(NSView *)_parent;

- (IBAction)OperationsCountButtonAction:(NSButton *)sender;
- (IBAction)PauseButtonAction:(NSButton *)sender;
- (IBAction)StopButtonAction:(NSButton *)sender;

@end
