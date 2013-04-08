//
//  OperationDialogAlert.m
//  Directories
//
//  Created by Pavel Dogurevich on 08.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationDialogAlert.h"

#import "Operation.h"

const int MaxButtonsCount = 5;

@implementation OperationDialogAlert
{
    NSAlert *m_Alert;
    Operation *m_Operation;
    
    int m_ButtonsResults[MaxButtonsCount];
    int m_ButtonsCount;
}
@synthesize Result = m_Result;

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo;
{
    assert(m_Operation);
    
    NSInteger button_number = returnCode - NSAlertFirstButtonReturn;
    assert(button_number >=0 && button_number < m_ButtonsCount);
    int result = m_ButtonsResults[button_number];
    m_Result = result;
    
    if (m_Result != OperationDialogResultNone)
        [m_Operation OnDialogClosed:self];
}

- (void)ShowDialogForWindow:(NSWindow *)_parent
{
    [m_Alert beginSheetModalForWindow:_parent
                        modalDelegate:self
                       didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
                          contextInfo:nil];
}

- (BOOL)IsVisible
{
    return [m_Alert.window isVisible];
}

- (void)HideDialog
{
    [NSApp endSheet:m_Alert.window returnCode:OperationDialogResultNone];
}

- (void)CloseDialogWithResult:(int)_result
{
    assert(_result != OperationDialogResultNone);
    
    if ([self IsVisible])
        [NSApp endSheet:m_Alert.window returnCode:_result];
    else
    {
        m_Result = _result;
        
        if (m_Result != OperationDialogResultNone)
            [m_Operation OnDialogClosed:self];
    }
}

- (BOOL)WaitForResult
{
    while (self.Result == OperationDialogResultNone)
    {
        usleep(33*1000);
    }
    
    return self.Result == OperationDialogResultStop;
}

- (void)OnDialogEnqueued:(Operation *)_operation
{
    m_Operation = _operation;
    m_Result = OperationDialogResultNone;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        m_Alert = [[NSAlert alloc] init];
        m_ButtonsCount = 0;
    }
    return self;
}

- (void)SetAlertStyle:(NSAlertStyle)_style
{
    [m_Alert setAlertStyle:_style];
}

- (void)SetIcon:(NSImage *)_icon
{
    [m_Alert setIcon:_icon];
}

- (void)SetMessageText:(NSString *)_text
{
    [m_Alert setMessageText:_text];
}

- (void)SetInformativeText:(NSString *)_text
{
    [m_Alert setInformativeText:_text];
}

- (NSButton *)AddButtonWithTitle:(NSString *)_title andResult:(int)_result
{
    assert(m_ButtonsCount < MaxButtonsCount);
    m_ButtonsResults[m_ButtonsCount++] = _result;
    return [m_Alert addButtonWithTitle:_title];
}

@end
