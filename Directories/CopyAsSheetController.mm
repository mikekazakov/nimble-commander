//
//  CopyAsSheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 23.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "CopyAsSheetController.h"

@implementation CopyAsSheetController
{
    CopyAsSheetCompletionHandler m_Handler;
    NSString *m_InitialName;
}

- (id)init {
    self = [super initWithWindowNibName:@"CopyAsSheetController"];
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    [[self TextField] setStringValue:m_InitialName];
    [[self TextField] becomeFirstResponder];
}

- (IBAction)OnOK:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::OK];
}

- (IBAction)OnCancel:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Cancel];
}

- (void)ShowSheet: (NSWindow *)_window initialname:(NSString*)_name handler:(CopyAsSheetCompletionHandler)_handler
{
    m_Handler = _handler;
    m_InitialName = _name;
    
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
