//
//  FileLinkNewHardlinkSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileLinkNewHardlinkSheetController.h"
#import "Common.h"

@implementation FileLinkNewHardlinkSheetController
{
    NSString *m_SourceName;
    FileLinkNewHardlinkSheetCompletionHandler m_Handler;
    
}

- (id)init {
    self = [super initWithWindowNibName:@"FileLinkNewHardlinkSheetController"];
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];    
    [self.Text setStringValue:[NSString stringWithFormat:@"Create a hardlink of \'%@\' to:", m_SourceName]];
    [self.window makeFirstResponder:self.LinkName];
}

- (void)ShowSheet:(NSWindow *)_window
       sourcename:(NSString*)_src
          handler:(FileLinkNewHardlinkSheetCompletionHandler)_handler
{
    m_SourceName = _src;
    m_Handler = _handler;
    
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
}

- (IBAction)OnCreate:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Create];
}

- (IBAction)OnCancel:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Cancel];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[self window] orderOut:self];
    
    if(m_Handler)
        m_Handler((int)returnCode);
    m_Handler = nil;
}

@end
