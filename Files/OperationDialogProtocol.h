//
//  OperationDialogProtocol.h
//  Directories
//
//  Created by Pavel Dogurevich on 08.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//


// Predefined OperationDialogProtocol results.
namespace OperationDialogResult
{
    // No result, dialog is not finished.
    constexpr int None = 0;

    // Dialog is finished and the job must stop execution. Closing with this result invokes
    // [ParentOperation Close].
    // Any dialog can be closed with this result by the application.
    constexpr int Stop = 1;

    // Dialog is finished and the job can continue execution.
    constexpr int Continue = 2;
    
    constexpr int Retry = 3;

    constexpr int Skip = 4;

    constexpr int SkipAll = 5;
    
    // Add your own custom results starting from this constant.
    constexpr int Custom = 100;
}


#ifdef __OBJC__
@class Operation;

@protocol OperationDialogProtocol <NSObject>

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
// if ([[m_Operation askUser] WaitForResult] == OperationDialogResult::Stop)
// {
//     SetStopped();
//     return;
// }
- (int)WaitForResult;

- (void)OnDialogEnqueued:(Operation *)_operation;

@end

#endif


