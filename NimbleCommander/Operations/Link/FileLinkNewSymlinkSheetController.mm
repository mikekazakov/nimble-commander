//
//  FileLinkNewSymlinkSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "FileLinkNewSymlinkSheetController.h"

@interface FileLinkNewSymlinkSheetController()

@property (strong) IBOutlet NSTextField *SourcePath;
@property (strong) IBOutlet NSTextField *LinkPath;

- (IBAction)OnCreate:(id)sender;
- (IBAction)OnCancel:(id)sender;

@end

@implementation FileLinkNewSymlinkSheetController
{
    string m_SrcPath;
    string m_LinkPath;
}

@synthesize sourcePath = m_SrcPath;
@synthesize linkPath = m_LinkPath;

- (void)windowDidLoad
{
    [super windowDidLoad];
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);    
    self.SourcePath.stringValue = [NSString stringWithUTF8StdString:m_SrcPath];
    self.LinkPath.stringValue = [NSString stringWithUTF8StdString:m_LinkPath];
    [self.window makeFirstResponder:self.LinkPath];
    GoogleAnalytics::Instance().PostScreenView("Symlink Create");
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

- (IBAction)OnCreate:(id)sender
{
    m_SrcPath = self.SourcePath.stringValue.fileSystemRepresentationSafe;
    m_LinkPath = self.LinkPath.stringValue.fileSystemRepresentationSafe;

    [super endSheet:NSModalResponseOK];
}

- (IBAction)OnCancel:(id)sender
{
    [super endSheet:NSModalResponseCancel];
}

@end
