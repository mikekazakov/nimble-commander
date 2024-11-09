// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CreateHardlinkDialog.h"
#include "../Internal.h"
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

using namespace nc::ops;

@interface NCOpsCreateHardlinkDialog ()

@property(strong, nonatomic) IBOutlet NSTextField *Text;
@property(strong, nonatomic) IBOutlet NSTextField *LinkName;
@property(nonatomic) bool isValid;

@end

@implementation NCOpsCreateHardlinkDialog {
    std::string m_SourceName;
    std::string m_Result;
}

@synthesize result = m_Result;
@synthesize Text;
@synthesize LinkName;
@synthesize isValid;

- (instancetype)initWithSourceName:(const std::string &)_src
{
    const auto nib_path = [Bundle() pathForResource:@"CreateHardlinkDialog" ofType:@"nib"];
    self = [super initWithWindowNibPath:nib_path owner:self];
    if( self ) {
        m_SourceName = _src;
        self.isValid = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    auto t = [NSString stringWithFormat:NSLocalizedString(@"Create a hardlink of \'%@\' to:", ""),
                                        [NSString stringWithUTF8StdString:m_SourceName]];
    self.Text.stringValue = t;
    [self.window makeFirstResponder:self.LinkName];
}

- (IBAction)OnCreate:(id) [[maybe_unused]] _sender
{
    if( self.LinkName.stringValue )
        m_Result = self.LinkName.stringValue.fileSystemRepresentationSafe;

    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)OnCancel:(id) [[maybe_unused]] _sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( nc::objc_cast<NSTextField>(notification.object) == self.LinkName )
        [self validate];
}

- (void)validate
{
    const auto v = self.LinkName.stringValue;
    self.isValid = v && v.length > 0;
}

@end
