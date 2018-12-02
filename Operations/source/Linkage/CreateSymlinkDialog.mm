// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CreateSymlinkDialog.h"
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

@interface NCOpsCreateSymlinkDialog()

@property (strong) IBOutlet NSTextField *SourcePath;
@property (strong) IBOutlet NSTextField *LinkPath;
@property bool isValid;
@end

@implementation NCOpsCreateSymlinkDialog
{
    std::string m_SrcPath;
    std::string m_LinkPath;
}

@synthesize sourcePath = m_SrcPath;
@synthesize linkPath = m_LinkPath;

- (instancetype) initWithSourcePath:(const std::string&)_src_path
                        andDestPath:(const std::string&)_link_path
{
    if( self = [super initWithWindowNibName:@"CreateSymlinkDialog"] ) {
        self.isValid = false;
        m_SrcPath  = _src_path;
        m_LinkPath = _link_path;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.SourcePath.stringValue = [NSString stringWithUTF8StdString:m_SrcPath];
    self.LinkPath.stringValue = [NSString stringWithUTF8StdString:m_LinkPath];
    
    [self.window makeFirstResponder:self.LinkPath];
    const auto r = [self.LinkPath.stringValue rangeOfCharacterFromSet:
                    [NSCharacterSet characterSetWithCharactersInString:@"/"]
                                               options:NSBackwardsSearch];
    if( r.location != NSNotFound )
        self.LinkPath.currentEditor.selectedRange = NSMakeRange(r.location+1,
                                                                self.LinkPath.stringValue.length);
    [self validate];
}

- (IBAction)OnCreate:(id)sender
{
    m_SrcPath = self.SourcePath.stringValue.fileSystemRepresentationSafe;
    m_LinkPath = self.LinkPath.stringValue.fileSystemRepresentationSafe;
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)OnCancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( objc_cast<NSTextField>(notification.object) == self.LinkPath )
        [self validate];
}

- (void)validate
{
    const auto v = self.LinkPath.stringValue;
    self.isValid = v && v.length > 0;
}

@end
