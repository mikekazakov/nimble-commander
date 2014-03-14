//
//  OperationsSummaryViewController.h
//  Directories
//
//  Created by Pavel Dogurevich on 23.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class OperationsController;
@class Operation;

@interface OperationsSummaryViewController : NSViewController

// Outlets and actions.
@property (weak) IBOutlet NSCollectionView *CollectionView;
@property (strong) IBOutlet NSArrayController *OperationsArrayController;
@property (readonly) OperationsController *OperationsController;
// Operation that is displayed in the summary view.
@property Operation *CurrentOperation;

- (id)initWithController:(OperationsController *)_controller
                  window:(NSWindow*)_wnd;
@property (strong) IBOutlet NSViewController *ScrollViewController;

@end
