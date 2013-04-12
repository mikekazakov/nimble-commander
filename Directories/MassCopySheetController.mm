//
//  MassCopySheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 12.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MassCopySheetController.h"

#include "Common.h"

@implementation MassCopySheetController
{
    MassCopySheetCompletionHandler m_Handler;
    NSString *m_InitialPath;
    bool m_IsCopying;
}

- (id)init {
    self = [super initWithWindowNibName:@"MassCopySheetController"];
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
 
    [[self TextField] setStringValue:m_InitialPath];
    [[self TextField] becomeFirstResponder];
    [[self window] setDefaultButtonCell:[[self CopyButton] cell]];
    
    if(m_IsCopying)
    {
        [self.DescriptionText setStringValue:@"Copy items to:"];
        [self.CopyButton setTitle:@"Copy"];
    }
    else
    {
        [self.DescriptionText setStringValue:@"Rename/move items to:"];
        [self.CopyButton setTitle:@"Rename"];
    }
}

- (IBAction)OnCopy:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Copy];
}

- (IBAction)OnCancel:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Cancel];    
}

- (void)ShowSheet:(NSWindow *)_window initpath:(NSString*)_path iscopying:(bool)_iscopying handler:(MassCopySheetCompletionHandler)_handler
{
    m_Handler = _handler;
    m_InitialPath = _path;
    m_IsCopying = _iscopying;

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
