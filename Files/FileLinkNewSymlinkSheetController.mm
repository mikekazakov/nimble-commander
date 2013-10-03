//
//  FileLinkNewSymlinkSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileLinkNewSymlinkSheetController.h"
#import "Common.h"

@implementation FileLinkNewSymlinkSheetController
{
    NSString *m_InitialSrcPath;
    NSString *m_InitialLinkPath;
    FileLinkNewSymlinkSheetCompletionHandler m_Handler;
}

- (id)init {
    self = [super initWithWindowNibName:@"FileLinkNewSymlinkSheetController"];
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [self.SourcePath setStringValue:m_InitialSrcPath];
    [self.LinkPath setStringValue:m_InitialLinkPath];
    [self.LinkPath becomeFirstResponder];
}

- (void)ShowSheet:(NSWindow *)_window
       sourcepath:(NSString*)_src_path
         linkpath:(NSString*)_link_path
          handler:(FileLinkNewSymlinkSheetCompletionHandler)_handler
{
    m_InitialSrcPath = _src_path;
    m_InitialLinkPath = _link_path;
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
}

@end
