//
//  OperationsController.h
//  Directories
//
//  Created by Pavel Dogurevich on 22.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Operation.h"

@interface OperationsController : NSObject

// Number of operations with at least one pending dialog.
@property (nonatomic) int OperationsWithDialogsCount;
@property (nonatomic) int OperationsCount;
@property (readonly, nonatomic) NSArray *Operations;
@property (readonly, nonatomic) bool AnyDialogShown;

// Stops all currently running operations and prevents addition of new operations.
- (void)Stop;

- (void)AddOperation:(Operation *)_op;
- (Operation *)GetOperation:(NSUInteger)_index;

@end
