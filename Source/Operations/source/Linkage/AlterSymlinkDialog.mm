// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AlterSymlinkDialog.h"
#include "../Internal.h"
#include <Utility/StringExtras.h>

using namespace nc::ops;

@interface NCOpsAlterSymlinkDialog ()

@property(strong, nonatomic) IBOutlet NSTextField *Text;
@property(strong, nonatomic) IBOutlet NSTextField *SourcePath;

- (IBAction)OnOk:(id)sender;
- (IBAction)OnCancel:(id)sender;

@end

@implementation NCOpsAlterSymlinkDialog {
    std::string m_SrcPath;
    std::string m_LinkPath;
}

@synthesize sourcePath = m_SrcPath;
@synthesize Text;
@synthesize SourcePath;

- (instancetype)initWithSourcePath:(const std::string &)_src_path andLinkName:(const std::string &)_link_name
{
    const auto nib_path = [Bundle() pathForResource:@"AlterSymlinkDialog" ofType:@"nib"];
    self = [super initWithWindowNibPath:nib_path owner:self];
    if( self ) {
        m_SrcPath = _src_path;
        m_LinkPath = _link_name;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    auto t = [NSString stringWithFormat:NSLocalizedString(@"Symbolic link \'%@\' points at:", ""),
                                        [NSString stringWithUTF8StdString:m_LinkPath]];
    self.Text.stringValue = t;
    self.SourcePath.stringValue = [NSString stringWithUTF8StdString:m_SrcPath];
    [self.window makeFirstResponder:self.SourcePath];
}

- (IBAction)OnOk:(id) [[maybe_unused]] _sender
{
    m_SrcPath = self.SourcePath.stringValue.fileSystemRepresentationSafe;
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)OnCancel:(id) [[maybe_unused]] _sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

@end
