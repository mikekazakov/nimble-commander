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
    void (^m_Handler)(NSModalResponse returnCode);
    __strong SheetController *m_Self;
}

- (id) init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self) {
    }
    return self;
}

- (bool) isSelfKeeping
{
    return false;
}

- (void) beginSheetForWindow:(NSWindow*)_wnd
           completionHandler:(void (^)(NSModalResponse returnCode))_handler
{
    assert(_handler != nil);
    if(self.isSelfKeeping)
        m_Self = self;
    
    m_Handler = [_handler copy];
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_9)
        [_wnd beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
            m_Handler(returnCode);
            m_Handler = nil;
        }];
    else
        [NSApp beginSheet:self.window
           modalForWindow:_wnd
            modalDelegate:self
           didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
              contextInfo:nil];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [self.window orderOut:self];
    m_Handler(returnCode);
    m_Handler = nil;
}

- (void) endSheet:(NSModalResponse)returnCode
{
    bool release_self = m_Self != nil;
    
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_9)
        [self.window.sheetParent endSheet:self.window
                               returnCode:returnCode];
    else
        [NSApp endSheet:self.window
             returnCode:returnCode];
    if(release_self)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            m_Self = nil;
        });
}

@end
