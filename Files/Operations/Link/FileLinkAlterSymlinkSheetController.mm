//
//  FileLinkAlterSymlinkSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <NimbleCommander/Core/GoogleAnalytics.h>
#include "FileLinkAlterSymlinkSheetController.h"

@interface FileLinkAlterSymlinkSheetController ()

@property (strong) IBOutlet NSTextField *Text;
@property (strong) IBOutlet NSTextField *SourcePath;

- (IBAction)OnOk:(id)sender;
- (IBAction)OnCancel:(id)sender;

@end

@implementation FileLinkAlterSymlinkSheetController
{
    string m_SrcPath;
    string m_LinkPath;
}

@synthesize sourcePath = m_SrcPath;

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.Text.stringValue = [NSString stringWithFormat:@"Symbolic link \'%@\' points at:", [NSString stringWithUTF8StdString:m_LinkPath]];
    self.SourcePath.stringValue = [NSString stringWithUTF8StdString:m_SrcPath];
    [self.window makeFirstResponder:self.SourcePath];
    GoogleAnalytics::Instance().PostScreenView("Symlink Altering");
}

- (void)showSheetFor:(NSWindow *)_window
          sourcePath:(const string&)_src_path
            linkPath:(const string&)_link_path
   completionHandler:(void (^)(NSModalResponse returnCode))_handler
{
    m_SrcPath = _src_path;
    m_LinkPath = _link_path;
    [super beginSheetForWindow:_window completionHandler:_handler];
}

- (IBAction)OnOk:(id)sender
{
    m_SrcPath = self.SourcePath.stringValue.fileSystemRepresentationSafe;
    [super endSheet:NSModalResponseOK];
}

- (IBAction)OnCancel:(id)sender
{
    [super endSheet:NSModalResponseCancel];
}

@end
