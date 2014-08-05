//
//  SheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 05/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "SheetController.h"
#import "sysinfo.h"

@implementation SheetController
{
    void (^m_Handler)(NSModalResponse returnCode); // for pre-10.9
}

- (id) init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self) {
    }
    return self;
}

- (void) beginSheetForWindow:(NSWindow*)_wnd
           completionHandler:(void (^)(NSModalResponse returnCode))_handler
{
    assert(_handler != nil);
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_9) {
        [_wnd beginSheet:self.window completionHandler:_handler];
    }
    else {
        m_Handler = _handler;
        [NSApp beginSheet:self.window
           modalForWindow:_wnd
            modalDelegate:self
           didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
              contextInfo:nil];
    }
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [self.window orderOut:self];
    m_Handler(returnCode);
    m_Handler = nil;
}

- (void) endSheet:(NSModalResponse)returnCode
{
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_9)
        [self.window.sheetParent endSheet:self.window
                               returnCode:returnCode];
    else
        [NSApp endSheet:self.window
             returnCode:returnCode];
}

@end
