//
//  GoToFolderSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 24.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "GoToFolderSheetController.h"
#import "Common.h"
#import "VFS.h"

static NSString *g_LastGoToKey = @"FilePanelsGeneralLastGoToFolder";

@implementation GoToFolderSheetController
{
    int (^m_Handler)(); // return VFS error code
}

- (id)init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self){
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if(NSString *last = [defaults stringForKey:g_LastGoToKey])
        [self.Text setStringValue:last];
    
    [self.Text setDelegate:self];
    [self controlTextDidChange:nil];
}

- (void)ShowSheet:(NSWindow *)_window handler:(int (^)())_handler
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
}

- (IBAction)OnGo:(id)sender
{
    int ret = m_Handler();
    if(ret == 0)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setValue:self.Text.stringValue forKey:g_LastGoToKey];

        [NSApp endSheet:[self window] returnCode:DialogResult::OK];
        m_Handler = nil;
    }
    else
    {
        // show error here
        [self.Error setStringValue:[VFSError::ToNSError(ret) localizedDescription]];
    }
}

- (IBAction)OnCancel:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Cancel];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    [self.GoButton setEnabled:self.Text.stringValue.length > 0];
}

@end
