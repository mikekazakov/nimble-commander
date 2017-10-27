// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CreateHardlinkDialog.h"
#include "../Internal.h"

using namespace nc::ops;

@interface NCOpsCreateHardlinkDialog ()

@property (strong) IBOutlet NSTextField *Text;
@property (strong) IBOutlet NSTextField *LinkName;
@property bool isValid;

@end


@implementation NCOpsCreateHardlinkDialog
{
    string m_SourceName;
    string m_Result;
}

@synthesize result = m_Result;

- (instancetype)initWithSourceName:(const string&)_src
{
    if( self = [super initWithWindowNibName:@"CreateHardlinkDialog"] ) {
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

- (IBAction)OnCreate:(id)sender
{
    if( self.LinkName.stringValue )
        m_Result = self.LinkName.stringValue.fileSystemRepresentationSafe;
    
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];    
}

- (IBAction)OnCancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( objc_cast<NSTextField>(notification.object) == self.LinkName )
        [self validate];
}

- (void)validate
{
    const auto v = self.LinkName.stringValue;
    self.isValid = v && v.length > 0;
}

@end
