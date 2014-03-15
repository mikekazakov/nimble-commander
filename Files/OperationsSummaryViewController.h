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

- (id)initWithController:(OperationsController *)_controller
                  window:(NSWindow*)_wnd;

// Outlets and actions.
@property (strong) IBOutlet NSCollectionView *CollectionView;
@property (strong) IBOutlet NSArrayController *OperationsArrayController;
@property (strong) IBOutlet NSViewController *ScrollViewController;
@property (readonly) OperationsController *OperationsController;

/**
 * Operation that is displayed in the summary view.
 */
@property Operation *CurrentOperation;

@end
