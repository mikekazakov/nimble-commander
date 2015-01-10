//
//  MessageBox.m
//  Directories
//
//  Created by Michael G. Kazakov on 27.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MessageBox.h"
#import "Common.h"
#import "sysinfo.h"

@implementation MessageBox
{
    id m_Self;
    void (^m_Handler)(NSModalResponse returnCode);
}

- (void)beginSheetModalForWindow:(NSWindow *)_for_window completionHandler:(void (^)(NSModalResponse returnCode))_handler
{
    m_Self = self;
    
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_9) {
        [super beginSheetModalForWindow:_for_window completionHandler:^(NSModalResponse returnCode) {
            _handler(returnCode);
            m_Self = nil;
        }];
    }
    else {
        m_Handler = _handler;
        dispatch_to_main_queue([=]{
            [self beginSheetModalForWindow:_for_window
                             modalDelegate:self
                            didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
                               contextInfo:nil];
        });
    }
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if(m_Handler) {
        m_Handler(returnCode);
        m_Handler = nil;
    }
    [self.window orderOut:nil];
    m_Self = nil;
}

@end
