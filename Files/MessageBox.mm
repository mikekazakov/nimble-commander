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
}

- (void)ShowSheetWithHandler: (NSWindow *)_for_window handler:(MessageBoxCompletionHandler)_handler
{
    m_Handler = _handler;
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
    {
        m_Handler((int)returnCode);
        m_Handler = nil;
    }
}

@end
