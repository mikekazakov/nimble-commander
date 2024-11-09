// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CreateSymlinkDialog.h"
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>
#include "../Internal.h"

using namespace nc::ops;

@interface NCOpsCreateSymlinkDialog ()

@property(strong, nonatomic) IBOutlet NSTextField *SourcePath;
@property(strong, nonatomic) IBOutlet NSTextField *LinkPath;
@property(nonatomic) bool isValid;
@end

@implementation NCOpsCreateSymlinkDialog {
    std::string m_SrcPath;
    std::string m_LinkPath;
}

@synthesize sourcePath = m_SrcPath;
@synthesize linkPath = m_LinkPath;
@synthesize SourcePath;
@synthesize LinkPath;
@synthesize isValid;

- (instancetype)initWithSourcePath:(const std::string &)_src_path andDestPath:(const std::string &)_link_path
{
    const auto nib_path = [Bundle() pathForResource:@"CreateSymlinkDialog" ofType:@"nib"];
    self = [super initWithWindowNibPath:nib_path owner:self];
    if( self ) {
        self.isValid = false;
        m_SrcPath = _src_path;
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
    const auto r =
        [self.LinkPath.stringValue rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]
                                                   options:NSBackwardsSearch];
    if( r.location != NSNotFound )
        self.LinkPath.currentEditor.selectedRange = NSMakeRange(r.location + 1, self.LinkPath.stringValue.length);
    [self validate];
}

- (IBAction)OnCreate:(id) [[maybe_unused]] _sender
{
    m_SrcPath = self.SourcePath.stringValue.fileSystemRepresentationSafe;
    m_LinkPath = self.LinkPath.stringValue.fileSystemRepresentationSafe;
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)OnCancel:(id) [[maybe_unused]] _sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( nc::objc_cast<NSTextField>(notification.object) == self.LinkPath )
        [self validate];
}

- (void)validate
{
    const auto v = self.LinkPath.stringValue;
    self.isValid = v && v.length > 0;
}

@end
