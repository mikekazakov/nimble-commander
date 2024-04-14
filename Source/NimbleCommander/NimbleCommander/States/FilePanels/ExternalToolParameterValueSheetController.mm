// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExternalToolParameterValueSheetController.h"
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

@interface ExternalToolParameterValueSheetController ()

@property(nonatomic) IBOutlet NSLayoutConstraint *buttonConstraint;
@property(nonatomic) IBOutlet NSView *valueBlockView;
@property(nonatomic) IBOutlet NSButton *okButton;
@property(nonatomic, strong) IBOutlet NSStackView *stackView;
@property(nonatomic, strong) IBOutlet NSTextField *promptLabel;

@end

@implementation ExternalToolParameterValueSheetController {
    std::vector<std::string> m_ValueNames;
    std::vector<std::string> m_Values;
    std::vector<NSTextField *> m_ValueFields;
    std::string m_ToolName;
}

@synthesize values = m_Values;
@synthesize buttonConstraint;
@synthesize valueBlockView;
@synthesize okButton;
@synthesize stackView;
@synthesize promptLabel;

- (id)initWithValueNames:(std::vector<std::string>)_names toolName:(const std::string &)_name
{
    self = [super init];
    if( self ) {
        assert(!_names.empty());
        m_ValueNames = std::move(_names);
        m_ToolName = _name;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    auto prompt_fmt = NSLocalizedString(@"Please provide parameters to run \"%@\"", "");
    self.promptLabel.stringValue =
        [NSString localizedStringWithFormat:prompt_fmt, [NSString stringWithUTF8StdString:m_ToolName]];

    m_Values.resize(m_ValueNames.size());
    int index = 0;
    for( auto &value_name : m_ValueNames ) {
        const auto label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        label.stringValue = !value_name.empty() ? [NSString stringWithUTF8StdString:(value_name + ":")]
                                                : [NSString stringWithFormat:@"Parameter #%d:", index];
        label.bordered = false;
        label.editable = false;
        label.drawsBackground = false;
        [self.stackView addView:label inGravity:NSStackViewGravityBottom];

        const auto value = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        value.stringValue = @"";
        value.bordered = true;
        value.editable = true;
        value.drawsBackground = true;
        value.continuous = true;
        m_ValueFields.emplace_back(value);
        [self.stackView addView:value inGravity:NSStackViewGravityBottom];

        [self.stackView setCustomSpacing:4. afterView:label];
        ++index;
    }
}

- (IBAction)onOK:(id) [[maybe_unused]] _sender
{
    for( size_t index = 0; index != m_Values.size(); ++index ) {
        m_Values[index] = m_ValueFields[index].stringValue.UTF8String;
    }

    [self endSheet:NSModalResponseOK];
}

- (IBAction)onCancel:(id) [[maybe_unused]] _sender
{
    [self endSheet:NSModalResponseCancel];
}

@end
