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

- (void)ShowDialogFor:(NSWindow *)_parent
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
    [self HideDialogWithResult:OperationDialogResultNone];
}

- (void)HideDialogWithResult:(OperationDialogResult)_result
{
    assert([self IsVisible]);
    assert(m_Operation);
    
    _Result = _result;
    
    [NSApp endSheet:self.window];
    [self.window orderOut:nil];
    
    [m_Operation OnDialogHidden:self];
}

- (void)SetOperation:(Operation *)_op
{
    m_Operation = _op;
}

- (BOOL)WaitForResult
{
    while (self.Result == OperationDialogResultNone) {
        usleep(33*1000);
    }
    
    return self.Result == OperationDialogResultStop;
}

@end
