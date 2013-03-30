//
//  OperationDialogController.h
//  Directories
//
//  Created by Pavel Dogurevich on 31.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Operation;

@interface OperationDialogController : NSWindowController

enum OperationDialogResult
{
    // No result, dialog is not finished. When dialog is hidden with this result,
    // the job still waits for result. Dialog can be shown again to user.
    OperationDialogResultNone,
    // Dialog is finished and the job can continue execution. Dialog is released.
    OperationDialogResultContinue,
    // Dialog is finished and the job must stop execution. Dialog is released.
    OperationDialogResultStop
};
@property volatile OperationDialogResult Result;

- (void)ShowDialogFor:(NSWindow *)_parent;
- (BOOL)IsVisible;
- (void)HideDialogWithResult:(OperationDialogResult)_result;

// Returns YES when dialog requires job to stop (Result is ResultStop).
// Should be used in job's internal thread.
// Example usage:
// if ([[m_Operation askUser] WaitForResult])
// {
//     SetStopped();
//     return;
// }
- (BOOL)WaitForResult;

- (void)SetOperation:(Operation *)_op;

@end

