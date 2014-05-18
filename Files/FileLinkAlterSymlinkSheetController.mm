//
//  FileLinkAlterSymlinkSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileLinkAlterSymlinkSheetController.h"
#import "Common.h"

@implementation FileLinkAlterSymlinkSheetController
{
    NSString *m_OriginalSourcePath;
    NSString *m_LinkName;
    FileLinkAlterSymlinkSheetCompletionHandler m_Handler;
}

- (id)init {
    self = [super initWithWindowNibName:@"FileLinkAlterSymlinkSheetController"];
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self.Text setStringValue: [NSString stringWithFormat:@"Symbolic link \'%@\' points at:", m_LinkName] ];
    [self.SourcePath setStringValue:m_OriginalSourcePath];
    [self.window makeFirstResponder:self.SourcePath];
}

- (void)ShowSheet:(NSWindow *)_window
       sourcepath:(NSString*)_src
         linkname:(NSString*)_link_name
          handler:(FileLinkAlterSymlinkSheetCompletionHandler)_handler
{
    m_OriginalSourcePath = _src;
    m_LinkName = _link_name;
    m_Handler = _handler;
    
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];    
}

- (IBAction)OnOk:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::OK];
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
