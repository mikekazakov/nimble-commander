// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DirectoryCreationDialog.h"
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>
#include "../Internal.h"

using namespace nc::ops;

@interface NCOpsDirectoryCreationDialog ()

@property(strong, nonatomic) IBOutlet NSTextField *TextField;
@property(strong, nonatomic) IBOutlet NSButton *CreateButton;
@property(nonatomic) bool isValid;
@end

@implementation NCOpsDirectoryCreationDialog {
    std::string m_Result;
    std::string m_Suggestion;
    std::function<bool(const std::string &)> m_ValidationCallback;
}

@synthesize result = m_Result;
@synthesize suggestion = m_Suggestion;
@synthesize validationCallback = m_ValidationCallback;
@synthesize TextField;
@synthesize CreateButton;
@synthesize isValid;

- (instancetype)init
{
    const auto nib_path = [Bundle() pathForResource:@"DirectoryCreationDialog" ofType:@"nib"];
    self = [super initWithWindowNibPath:nib_path owner:self];
    if( self ) {
        self.isValid = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    if( auto v = [NSString stringWithUTF8StdString:m_Suggestion] )
        self.TextField.stringValue = v;
    [self.window makeFirstResponder:self.TextField];
    [self validate];
}

- (IBAction)OnCreate:(id) [[maybe_unused]] _sender
{
    if( !self.TextField.stringValue || !self.TextField.stringValue.length )
        return;

    if( auto p = self.TextField.stringValue.fileSystemRepresentation )
        m_Result = p;

    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)OnCancel:(id) [[maybe_unused]] _sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( nc::objc_cast<NSTextField>(notification.object) == self.TextField )
        [self validate];
}

- (void)validate
{
    const auto v = self.TextField.stringValue;
    if( !v ) {
        self.isValid = false;
    }
    else {
        if( m_ValidationCallback )
            self.isValid = m_ValidationCallback(v.UTF8String);
        else
            self.isValid = v.length > 0;
    }
}

@end
