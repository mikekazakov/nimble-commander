//
//  MessageBox.m
//  Directories
//
//  Created by Michael G. Kazakov on 27.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MessageBox.h"
#import "Common.h"

@implementation MessageBox
{
    MessageBoxCompletionHandler m_Handler;
    volatile int *m_Ptr;
}

- (void)ShowSheet: (NSWindow *)_for_window ptr:(volatile int*)_retptr
{
    m_Handler = 0;
    m_Ptr = _retptr;
    dispatch_to_main_queue( ^(){
        [self beginSheetModalForWindow:_for_window
                         modalDelegate:self
                        didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
                           contextInfo:nil];
    });    
}

- (void)ShowSheetWithHandler: (NSWindow *)_for_window handler:(MessageBoxCompletionHandler)_handler
{
    m_Handler = _handler;
    m_Ptr = 0;
    dispatch_to_main_queue( ^(){
    [self beginSheetModalForWindow:_for_window
                     modalDelegate:self
                     didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
                       contextInfo:nil];
    });
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[self window] orderOut:nil];
    if(m_Handler)
        m_Handler((int)returnCode);
    if(m_Ptr)
        *m_Ptr = (int)returnCode;

}

@end


void MessageBoxRetryCancel(NSString *_text1, NSString *_text2, NSWindow *_wnd, volatile int *_ret)
{
    *_ret = 0;
    MessageBox* mb = [MessageBox new];
    [mb setAlertStyle:NSCriticalAlertStyle];
    [mb setMessageText:_text1];
    [mb setInformativeText:_text2];
    [mb addButtonWithTitle:@"Retry"];
    [mb addButtonWithTitle:@"Cancel"];
    [mb ShowSheet:_wnd ptr:_ret];
}

void MessageBoxRetrySkipCancel(NSString *_text1, NSString *_text2, NSWindow *_wnd, volatile int *_ret)
{
    *_ret = 0;
    MessageBox* mb = [MessageBox new];
    [mb setAlertStyle:NSCriticalAlertStyle];
    [mb setMessageText:_text1];
    [mb setInformativeText:_text2];
    [mb addButtonWithTitle:@"Retry"];
    [mb addButtonWithTitle:@"Skip"];    
    [mb addButtonWithTitle:@"Cancel"];
    [mb ShowSheet:_wnd ptr:_ret];
}

void MessageBoxRetrySkipSkipallCancel(NSString *_text1, NSString *_text2, NSWindow *_wnd, volatile int *_ret)
{
    *_ret = 0;
    MessageBox* mb = [MessageBox new];
    [mb setAlertStyle:NSCriticalAlertStyle];
    [mb setMessageText:_text1];
    [mb setInformativeText:_text2];
    [mb addButtonWithTitle:@"Retry"];
    [mb addButtonWithTitle:@"Skip"];
    [mb addButtonWithTitle:@"Skip all"];
    [mb addButtonWithTitle:@"Cancel"];
    [mb ShowSheet:_wnd ptr:_ret];
}

void MessageBoxOverwriteAppendCancel(NSString *_text1, NSString *_text2, NSWindow *_wnd, volatile int *_ret)
{
    *_ret = 0;
    MessageBox* mb = [MessageBox new];
    [mb setAlertStyle:NSCriticalAlertStyle];
    [mb setMessageText:_text1];
    [mb setInformativeText:_text2];
    [mb addButtonWithTitle:@"Overwrite"];
    [mb addButtonWithTitle:@"Append"];
    [mb addButtonWithTitle:@"Cancel"];
    [mb ShowSheet:_wnd ptr:_ret];
}

void MessageBoxOverwriteOverwriteallAppendAppenallSkipSkipAllCancel(NSString *_text1, NSString *_text2, NSWindow *_wnd, volatile int *_ret)
{
    // TODO: delete this shit and implemet a message box with "remember choise" check box
    *_ret = 0;
    MessageBox* mb = [MessageBox new];
    [mb setAlertStyle:NSCriticalAlertStyle];
    [mb setMessageText:_text1];
    [mb setInformativeText:_text2];
    [mb addButtonWithTitle:@"Overwrite"];
    [mb addButtonWithTitle:@"Overwrite all"];
    [mb addButtonWithTitle:@"Append"];
    [mb addButtonWithTitle:@"Append all"];
    [mb addButtonWithTitle:@"Skip"];
    [mb addButtonWithTitle:@"Skip all"];    
    [mb addButtonWithTitle:@"Cancel"];
    [mb ShowSheet:_wnd ptr:_ret];
}
