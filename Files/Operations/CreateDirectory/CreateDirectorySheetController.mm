//
//  CreateDirectorySheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 01.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "../../GoogleAnalytics.h"
#include "CreateDirectorySheetController.h"

@interface CreateDirectorySheetController()

- (IBAction)OnCreate:(id)sender;
- (IBAction)OnCancel:(id)sender;
@property (strong) IBOutlet NSTextField *TextField;
@property (strong) IBOutlet NSButton *CreateButton;

@end


@implementation CreateDirectorySheetController
{
    string m_Result;
}

@synthesize result = m_Result;

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self.window makeFirstResponder:self.TextField];
    GoogleAnalytics::Instance().PostScreenView("Create Directory");
}

- (IBAction)OnCreate:(id)sender
{
    if( !self.TextField.stringValue || !self.TextField.stringValue.length )
        return;
    
    if( auto p = self.TextField.stringValue.fileSystemRepresentation )
        m_Result = p;
    
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnCancel:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

@end
