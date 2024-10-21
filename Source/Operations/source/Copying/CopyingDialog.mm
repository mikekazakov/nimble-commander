// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/CommonPaths.h>
#include <Base/algo.h>
#include "../Internal.h"
#include "DisclosureViewController.h"
#include "CopyingDialog.h"
#include "Copying.h"
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>
#include <Operations/FilenameTextControl.h>

using namespace nc::ops;

// removes entries of ".." and "."
// quite a bad implementation with O(n^2) complexity and possibly some allocations
static std::string MakeCanonicPath(std::string _input)
{
    using namespace std::literals;

    const auto dotdot = "/../"s;
    auto pos = _input.find(dotdot);
    if( pos != std::string::npos && pos > 0 ) {
        auto sl = _input.rfind('/', pos - 1);
        if( sl != std::string::npos ) {
            _input.erase(sl + 1, pos - sl + dotdot.size() - 1);
            return MakeCanonicPath(std::move(_input));
        }
    }

    const auto dot = "/./"s;
    pos = _input.find(dot);
    if( pos != std::string::npos ) {
        _input.erase(pos, 2);
        return MakeCanonicPath(std::move(_input));
    }

    return _input;
}

@interface NCOpsCopyingDialog ()

@property(strong, nonatomic) IBOutlet NSButton *CopyButton;
@property(strong, nonatomic) IBOutlet NSTextField *TextField;
@property(strong, nonatomic) IBOutlet NSTextField *DescriptionText;
@property(strong, nonatomic) IBOutlet NSButton *PreserveSymlinksCheckbox;
@property(strong, nonatomic) IBOutlet NSButton *CopyXattrsCheckbox;
@property(strong, nonatomic) IBOutlet NSButton *CopyFileTimesCheckbox;
@property(strong, nonatomic) IBOutlet NSButton *CopyUNIXFlagsCheckbox;
@property(strong, nonatomic) IBOutlet NSButton *CopyUnixOwnersCheckbox;
@property(strong, nonatomic) IBOutlet NSButton *CopyButtonStringStub;
@property(strong, nonatomic) IBOutlet NSButton *RenameButtonStringStub;
@property(nonatomic) bool isValidInput;
@property(strong, nonatomic) IBOutlet DisclosureViewController *DisclosedViewController;
@property(strong, nonatomic) IBOutlet NSStackView *StackView;
@property(strong, nonatomic) IBOutlet NSView *PathPart;
@property(strong, nonatomic) IBOutlet NSView *ButtonsPart;
@property(strong, nonatomic) IBOutlet NSPopUpButton *VerifySetting;

@end

@implementation NCOpsCopyingDialog {
    std::vector<VFSListingItem> m_SourceItems;
    VFSHostPtr m_SourceHost;       // can be nullptr in case of non-uniform listing
    std::string m_SourceDirectory; // may be "" if SourceHost is nullptr
    std::string m_InitialDestination;
    VFSHostPtr m_DestinationHost; // can be nullptr in case of non-uniform listing
    CopyingOptions m_Options;

    std::string m_ResultDestination;
    VFSHostPtr m_ResultHost;

    std::shared_ptr<nc::ops::DirectoryPathAutoCompetion> m_AutoCompletion;
    NCFilepathAutoCompletionDelegate *m_AutoCompletionDelegate;
}

@synthesize resultDestination = m_ResultDestination;
@synthesize resultHost = m_ResultHost;
@synthesize resultOptions = m_Options;
@synthesize CopyButton;
@synthesize TextField;
@synthesize DescriptionText;
@synthesize PreserveSymlinksCheckbox;
@synthesize CopyXattrsCheckbox;
@synthesize CopyFileTimesCheckbox;
@synthesize CopyUNIXFlagsCheckbox;
@synthesize CopyUnixOwnersCheckbox;
@synthesize CopyButtonStringStub;
@synthesize RenameButtonStringStub;
@synthesize isValidInput;
@synthesize DisclosedViewController;
@synthesize StackView;
@synthesize PathPart;
@synthesize ButtonsPart;
@synthesize VerifySetting;

- (instancetype)initWithItems:(std::vector<VFSListingItem>)_source_items
                    sourceVFS:(const VFSHostPtr &)_source_host
              sourceDirectory:(const std::string &)_source_directory
           initialDestination:(const std::string &)_initial_destination
               destinationVFS:(const VFSHostPtr &)_destination_host
             operationOptions:(const CopyingOptions &)_options
{
    const auto nib_path = [Bundle() pathForResource:@"CopyingDialog" ofType:@"nib"];
    self = [super initWithWindowNibPath:nib_path owner:self];
    if( self ) {
        m_SourceItems = std::move(_source_items);
        m_SourceDirectory = _source_directory;
        m_SourceHost = _source_host;
        m_InitialDestination = _initial_destination;
        m_DestinationHost = _destination_host;
        m_Options = _options;
        if( m_DestinationHost ) {
            m_AutoCompletion = std::make_shared<nc::ops::DirectoryPathAutoCompletionImpl>(m_DestinationHost);
            m_AutoCompletionDelegate = [[NCFilepathAutoCompletionDelegate alloc] init];
            m_AutoCompletionDelegate.completion = m_AutoCompletion;
            m_AutoCompletionDelegate.isNativeVFS = m_DestinationHost->IsNativeFS();
        }

        self.isValidInput = [self validateInput:_initial_destination];
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self.DisclosedViewController toggleDisclosure:self];
    [self.StackView insertView:self.PathPart atIndex:0 inGravity:NSStackViewGravityTop];
    [self.StackView insertView:self.DisclosedViewController.view atIndex:0 inGravity:NSStackViewGravityBottom];
    [self.StackView insertView:self.ButtonsPart atIndex:1 inGravity:NSStackViewGravityBottom];
    [self.window.contentView updateConstraintsForSubtreeIfNeeded];
    [self.window makeFirstResponder:self.TextField];

    auto initial_path = [NSString stringWithUTF8StdString:m_InitialDestination];

    self.TextField.stringValue = initial_path;
    if( initial_path.length > 0 && [initial_path characterAtIndex:0] != u'/' ) {
        // short path, find if there's an extension, if so - select only filename without .ext
        NSRange r = [initial_path rangeOfString:@"." options:NSBackwardsSearch];
        if( r.location != NSNotFound )
            self.TextField.currentEditor.selectedRange = NSMakeRange(0, r.location);
    }

    const int amount = static_cast<int>(m_SourceItems.size());
    if( m_Options.docopy ) {
        if( amount > 1 )
            self.DescriptionText.stringValue = [NSString
                stringWithFormat:NSLocalizedString(@"Copy %@ items to:", "Copy files sheet prompt, copying many files"),
                                 [NSNumber numberWithInt:amount]];
        else
            self.DescriptionText.stringValue =
                [NSString stringWithFormat:NSLocalizedString(@"Copy \u201c%@\u201d to:",
                                                             "Copy files sheet prompt, copying single file"),
                                           [NSString stringWithUTF8String:m_SourceItems.front().FilenameC()]];
        self.CopyButton.title = self.CopyButtonStringStub.title;
    }
    else {
        if( amount > 1 )
            self.DescriptionText.stringValue =
                [NSString stringWithFormat:NSLocalizedString(@"Rename/move %@ items to:",
                                                             "Move files sheet prompt, moving many files"),
                                           [NSNumber numberWithInt:amount]];
        else
            self.DescriptionText.stringValue =
                [NSString stringWithFormat:NSLocalizedString(@"Rename/move \u201c%@\u201d to:",
                                                             "Move files sheet prompt, moving single file"),
                                           [NSString stringWithUTF8String:m_SourceItems.front().FilenameC()]];
        self.CopyButton.title = self.RenameButtonStringStub.title;
    }
    [self.VerifySetting selectItemWithTag:static_cast<int>(m_Options.verification)];
}

- (IBAction)OnCopy:(id) [[maybe_unused]] _sender
{
    [self validate];
    [self fillOptions];
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)OnCancel:(id) [[maybe_unused]] _sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (bool)validateInput:(const std::string &)_input
{
    auto not_valid = [self] {
        m_ResultDestination = "";
        m_ResultHost = nullptr;
        return false;
    };

    if( _input.empty() )
        return not_valid();

    std::string input = _input;

    if( input.front() == '/' ) {
        if( !m_DestinationHost )
            return not_valid();

        // do '..'/'.' stuff
        input = MakeCanonicPath(input);

        m_ResultDestination = input;
        m_ResultHost = m_DestinationHost;
    }
    else {
        if( !m_SourceHost )
            return not_valid();

        if( m_SourceHost->IsNativeFS() && _input.starts_with("~/") ) // input is relative to home dir
            input.replace(0, 2, nc::base::CommonPaths::Home());
        else if( m_SourceHost->IsNativeFS() && _input.starts_with("~") ) // input is relative to home dir
            input.replace(0, 1, nc::base::CommonPaths::Home());
        else // input is relative to source base dir
            input = m_SourceDirectory + input;

        // do '..'/'.' stuff
        input = MakeCanonicPath(input);

        m_ResultDestination = input;
        m_ResultHost = m_SourceHost;
    }

    return true;
}

- (void)fillOptions
{
    m_Options.preserve_symlinks = self.PreserveSymlinksCheckbox.state == NSControlStateValueOn;
    m_Options.copy_xattrs = self.CopyXattrsCheckbox.state == NSControlStateValueOn;
    m_Options.copy_file_times = self.CopyFileTimesCheckbox.state == NSControlStateValueOn;
    m_Options.copy_unix_flags = self.CopyUNIXFlagsCheckbox.state == NSControlStateValueOn;
    m_Options.copy_unix_owners = self.CopyUnixOwnersCheckbox.state == NSControlStateValueOn;
    m_Options.verification = static_cast<CopyingOptions::ChecksumVerification>(self.VerifySetting.selectedTag);
}

- (void)validate
{
    NSString *val = self.TextField.stringValue;
    self.isValidInput = [self validateInput:(val ? val.fileSystemRepresentationSafe : "")];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( nc::objc_cast<NSTextField>(notification.object) == self.TextField )
        [self validate];
}

- (BOOL)control:(NSControl *)_control textView:(NSTextView *)_text_view doCommandBySelector:(SEL)_command_selector
{
    if( _control == self.TextField && _command_selector == @selector(complete:) && m_AutoCompletionDelegate ) {
        return [m_AutoCompletionDelegate control:_control textView:_text_view doCommandBySelector:_command_selector];
    }
    return false;
}

@end
