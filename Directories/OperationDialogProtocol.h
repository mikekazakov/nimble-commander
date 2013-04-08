//
//  OperationDialogProtocol.h
//  Directories
//
//  Created by Pavel Dogurevich on 08.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Operation;

@protocol OperationDialogProtocol <NSObject>

// Predefined dialog results.
enum
{
    // No result, dialog is not finished.
    OperationDialogResultNone       = 0,
    // Dialog is finished and the job must stop execution. Closing with this result invokes
    // [ParentOperation Close].
    // Any dialog can be closed with this result by the application.
    OperationDialogResultStop       = 1,
    // Dialog is finished and the job can continue execution.
    OperationDialogResultContinue   = 2,
    // Add your own custom results starting from this constant.
    OperationDialogResultCustom     = 100
};
@property (readonly) volatile int Result;

- (void)ShowDialogForWindow:(NSWindow *)_parent;
- (BOOL)IsVisible;
// Hide dialog without any result. Dialog can be presented to user again by ShowDialogForWindow.
// WaitForResult still blocks.
- (void)HideDialog;
// Close dialog with result. Dialog is released, WaitForResult returns with result.
- (void)CloseDialogWithResult:(int)_result;

// Waits for dialog to close with result. Should be used in job's internal thread.
// Example usage:
// if ([[m_Operation askUser] WaitForResult] == OperationDialogResultStop)
// {
//     SetStopped();
//     return;
// }
- (BOOL)WaitForResult;

- (void)OnDialogEnqueued:(Operation *)_operation;

@end
