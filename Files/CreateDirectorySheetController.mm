//
//  CreateDirectorySheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 01.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "CreateDirectorySheetController.h"

@implementation CreateDirectorySheetController
{
    CreateDirectorySheetCompletionHandler m_Handler;
}

- (id)init {
    self = [super initWithWindowNibName:@"CreateDirectorySheetController"];
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [[self TextField] becomeFirstResponder];
}

- (IBAction)OnCreate:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Create];
}

- (IBAction)OnCancel:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Cancel];
}

- (void)ShowSheet: (NSWindow *)_window handler:(CreateDirectorySheetCompletionHandler)_handler
{
    m_Handler = _handler;
    
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[self window] orderOut:self];
    
    if(m_Handler)
        m_Handler((int)returnCode);
}

@end
