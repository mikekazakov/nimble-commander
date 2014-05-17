//
//  FTPConnectionSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 17.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "FTPConnectionSheetController.h"

@implementation FTPConnectionSheetController
{
    NSWindow                   *m_ParentWindow;
    void                      (^m_OnConnect)();
}

- (id) init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self) {       
    }
    return self;
}

- (void)ShowSheet:(NSWindow *) _window
          handler:(void(^)())_on_connect
{
    m_ParentWindow = _window;
    m_OnConnect = _on_connect;
    
    [NSApp beginSheet:self.window
       modalForWindow:_window
        modalDelegate:self
       didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
          contextInfo:nil];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [self.window orderOut:self];
    m_ParentWindow = nil;
    m_OnConnect = nil;
}

- (IBAction)OnConnect:(id)sender
{
    m_OnConnect();
    [NSApp endSheet:self.window];
}

- (IBAction)OnClose:(id)sender
{
    [NSApp endSheet:self.window];
}

@end
