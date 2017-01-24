//
//  OperationsSummaryViewController.h
//  Directories
//
//  Created by Pavel Dogurevich on 23.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

@class OperationsController;
@class Operation;

@interface OperationsSummaryViewController : NSViewController

- (id)initWithController:(OperationsController *)_controller
                  window:(NSWindow*)_wnd;

@property (readonly) OperationsController *OperationsController;
@property (readonly) NSView *backgroundView;

/**
 * Operation that is displayed in the summary view.
 */
@property Operation *CurrentOperation;

@end
