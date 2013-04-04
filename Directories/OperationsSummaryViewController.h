//
//  OperationsSummaryViewController.h
//  Directories
//
//  Created by Pavel Dogurevich on 23.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class OperationsController;

@interface OperationsSummaryViewController : NSViewController

// Outlets and actions.
@property (weak) IBOutlet NSTextField *OperationsCountLabel;
@property (weak) IBOutlet NSTextField *DialogsCountLabel;
@property (weak) IBOutlet NSTextField *NoOperationsLabel;
@property (weak) IBOutlet NSCollectionView *CollectionView;
@property (strong) IBOutlet NSScrollView *ScrollView;
@property (strong) IBOutlet NSArrayController *OperationsArrayController;
@property (weak) IBOutlet NSBox *Box;
- (IBAction)ShowOpListButtonAction:(NSButton *)sender;
- (IBAction)OperationPauseButtonAction:(NSButton *)sender;
- (IBAction)OperationStopButtonAction:(NSButton *)sender;
- (IBAction)OperationDialogButtonAction:(NSButton *)sender;


@property (readonly) OperationsController *OperationsController;

- (id)initWthController:(OperationsController *)_controller;
- (void)AddViewTo:(NSView *)_parent;

@end
