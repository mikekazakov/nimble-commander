//
//  OperationDialogAlert.m
//  Directories
//
//  Created by Pavel Dogurevich on 08.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <NimbleCommander/Core/Alert.h>
#include "Operation.h"
#include "OperationDialogAlert.h"

@implementation OperationDialogAlert
{
    Alert              *m_Alert;
    __weak Operation   *m_Operation;
    int                 m_Result;
}

@synthesize Result = m_Result;

- (id)init
{
    self = [super init];
    if (self) {
        m_Alert = [[Alert alloc] init];
    }
    return self;
}

- (id)initRetrySkipSkipAllAbortHide:(BOOL)_enable_skip
{
    
    self = [self init];
    if (self) {
        [self AddButtonWithTitle:NSLocalizedStringFromTable(@"Retry",
                                                            @"Operations",
                                                            "Error dialog button title")
                       andResult:OperationDialogResult::Retry];
        if (_enable_skip) {
            [self AddButtonWithTitle:NSLocalizedStringFromTable(@"Skip",
                                                                @"Operations",
                                                                "Error dialog button title")
                           andResult:OperationDialogResult::Skip];
            [self AddButtonWithTitle:NSLocalizedStringFromTable(@"Skip All",
                                                                @"Operations",
                                                                "Error dialog button title")
                           andResult:OperationDialogResult::SkipAll];
        }
        [self AddButtonWithTitle:NSLocalizedStringFromTable(@"Abort",
                                                            @"Operations",
                                                            "Error dialog button title")
                       andResult:OperationDialogResult::Stop];
        [self AddButtonWithTitle:NSLocalizedStringFromTable(@"Hide",
                                                            @"Operations",
                                                            "Error dialog button title")
                       andResult:OperationDialogResult::None];
    }
    return self;
}

- (void)showDialogForWindow:(NSWindow *)_parent
{
    dispatch_assert_main_queue();
    
    [m_Alert beginSheetModalForWindow:_parent completionHandler:^(NSModalResponse returnCode) {
        m_Result = (int)returnCode;
        if( m_Result != OperationDialogResult::None )
            [(Operation*)m_Operation OnDialogClosed:self];
    }];
    
}

- (BOOL)IsVisible
{
    return m_Alert.window.isVisible;
}

- (void)HideDialog
{
    dispatch_assert_main_queue();
    
    if( self.IsVisible )
        [m_Alert.window.parentWindow endSheet:m_Alert.window returnCode:OperationDialogResult::None];
}

- (void)CloseDialogWithResult:(int)_result
{
    if( _result == OperationDialogResult::None )
        return;
    
    [self HideDialog];
    m_Result = _result;
    [(Operation*)m_Operation OnDialogClosed:self];
}

- (int)WaitForResult
{
    dispatch_assert_background_queue();
    
    while( self.Result == OperationDialogResult::None )
        usleep(20*1000);
    
    return self.Result;
}

- (void)OnDialogEnqueued:(Operation *)_operation
{
    dispatch_assert_main_queue();
    
    m_Operation = _operation;
    m_Result = OperationDialogResult::None;
}

- (void)SetAlertStyle:(NSAlertStyle)_style
{
    m_Alert.alertStyle = _style;
}

- (void)SetIcon:(NSImage *)_icon
{
    m_Alert.icon = _icon;
}

- (void)SetMessageText:(NSString *)_text
{
    m_Alert.messageText = _text;
}

- (void)SetInformativeText:(NSString *)_text
{
    m_Alert.informativeText = _text;
}

- (NSButton *)AddButtonWithTitle:(NSString *)_title andResult:(int)_result
{
    NSButton *b = [m_Alert addButtonWithTitle:_title];
    b.tag = _result;
    return b;
}

@end
