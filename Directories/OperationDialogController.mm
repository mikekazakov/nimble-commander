//
//  OperationDialogController.m
//  Directories
//
//  Created by Pavel Dogurevich on 31.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationDialogController.h"

#import "Operation.h"

@interface OperationDialogController ()

@end

@implementation OperationDialogController
{
    Operation *m_Operation;
}
@synthesize Result = m_Result;

- (void)ShowDialogForWindow:(NSWindow *)_parent
{    
    [NSApp beginSheet: self.window
       modalForWindow: _parent
        modalDelegate: nil
       didEndSelector: nil
          contextInfo: nil];
}

- (BOOL)IsVisible
{
    return [self.window isVisible];
}

- (void)HideDialog
{
    assert([self IsVisible]);
    
    [NSApp endSheet:self.window];
    [self.window orderOut:nil];
}

- (void)CloseDialogWithResult:(int)_result
{
    assert(m_Operation);
    assert(_result != OperationDialogResultNone);
    
    m_Result = _result;
 
    if ([self IsVisible]) [self HideDialog];
    
    [m_Operation OnDialogClosed:self];
}

- (BOOL)WaitForResult
{
    while (self.Result == OperationDialogResultNone) {
        usleep(33*1000);
    }
    
    return self.Result == OperationDialogResultStop;
}

- (void)OnDialogEnqueued:(Operation *)_operation
{
    m_Operation = _operation;
    m_Result = OperationDialogResultNone;
}

@end
