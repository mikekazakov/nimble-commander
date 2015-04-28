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
    
    [super beginSheetModalForWindow:_for_window completionHandler:^(NSModalResponse returnCode) {
        _handler(returnCode);
        m_Self = nil;
    }];
}


@end
