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
    function<void()> m_Handler; // return VFS error code
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
    
    if(NSString *last = [NSUserDefaults.standardUserDefaults stringForKey:g_LastGoToKey])
        self.Text.stringValue = last;
    
    self.Text.delegate = self;
    [self controlTextDidChange:nil];
}

- (void)showSheetWithParentWindow:(NSWindow *)_window handler:(function<void()>)_handler
{
    m_Handler = _handler;
    [_window beginSheet:self.window
      completionHandler:^(NSModalResponse returnCode){}
     ];
}

- (IBAction)OnGo:(id)sender
{
    m_Handler();
}

- (void)tellLoadingResult:(int)_code
{
    if(_code == 0) {
        [NSUserDefaults.standardUserDefaults setValue:self.Text.stringValue forKey:g_LastGoToKey];
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseStop];
        m_Handler = nullptr;
    }
    else { // show error here
        self.Error.stringValue = VFSError::ToNSError(_code).localizedDescription;
    }
}

- (IBAction)OnCancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseStop];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    self.GoButton.enabled = self.Text.stringValue.length > 0;
}

@end
