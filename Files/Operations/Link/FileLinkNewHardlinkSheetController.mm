//
//  FileLinkNewHardlinkSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "../../Common.h"
#include "FileLinkNewHardlinkSheetController.h"

@interface FileLinkNewHardlinkSheetController ()

@property (strong) IBOutlet NSTextField *Text;
@property (strong) IBOutlet NSTextField *LinkName;

- (IBAction)OnCreate:(id)sender;
- (IBAction)OnCancel:(id)sender;

@end


@implementation FileLinkNewHardlinkSheetController
{
    string m_SourceName;
    string m_Result;
}

@synthesize result = m_Result;

- (void)windowDidLoad
{
    [super windowDidLoad];    
    [self.Text setStringValue:[NSString stringWithFormat:@"Create a hardlink of \'%@\' to:", [NSString stringWithUTF8StdString:m_SourceName]]];
    [self.window makeFirstResponder:self.LinkName];
}

- (IBAction)OnCreate:(id)sender
{
    if( self.LinkName.stringValue )
        m_Result = self.LinkName.stringValue.fileSystemRepresentationSafe;
        
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnCancel:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (void)showSheetFor:(NSWindow *)_window
      withSourceName:(const string&)_src
   completionHandler:(void (^)(NSModalResponse returnCode))_handler
{
    m_SourceName = _src;
    [super beginSheetForWindow:_window completionHandler:_handler];
}

@end
