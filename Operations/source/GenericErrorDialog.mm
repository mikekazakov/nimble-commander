// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "GenericErrorDialog.h"
#include <VFS/VFS.h>
#include "Internal.h"
#include "ModalDialogResponses.h"
#include <Habanero/dispatch_cpp.h>
#include <Utility/ObjCpp.h>

using namespace nc::ops;

@interface NCOpsGenericErrorDialog ()
@property (strong) IBOutlet NSTextField *pathLabel;
@property (strong) IBOutlet NSTextField *errorLabel;
@property (strong) IBOutlet NSTextField *messageLabel;
@property (strong) IBOutlet NSImageView *appIcon;
@property (strong) IBOutlet NSImageView *dialogIcon;
@property (strong) IBOutlet NSButton *applyToAllCheckBox;

@end

@implementation NCOpsGenericErrorDialog
{
    GenericErrorDialogStyle m_Style;
    NSModalResponse m_EscapeButtonResponse;
    NSString* m_Message;
    NSString* m_Path;
    NSString* m_Error;
    int m_ErrorNo;
    bool m_ShowApplyToAll;
    std::vector<std::pair<NSString*,NSModalResponse>> m_Buttons;
    std::shared_ptr<nc::ops::AsyncDialogResponse> m_Context;
}

@synthesize escapeButtonResponse = m_EscapeButtonResponse;
@synthesize message = m_Message;
@synthesize path = m_Path;
@synthesize error = m_Error;
@synthesize showApplyToAll = m_ShowApplyToAll;

- (instancetype)initWithContext:(std::shared_ptr<nc::ops::AsyncDialogResponse>)_context
{
    dispatch_assert_main_queue();
    self = [super initWithWindowNibName:@"GenericErrorDialog"];
    if( self ) {
        m_Context = _context;
        m_ShowApplyToAll = false;
        m_Style = GenericErrorDialogStyle::Caution;
        m_EscapeButtonResponse = nc::ops::NSModalResponseCancel;
        m_ErrorNo = VFSError::Ok;
    
    }
    return self;
}

- (instancetype)init
{
    return [self initWithContext:nullptr];
}

- (void)windowDidLoad {
    [super windowDidLoad];

    [self placeButtons];
    
    self.dialogIcon.image = m_Style == GenericErrorDialogStyle::Caution ?
        [Bundle() imageForResource:@"AlertCautionBig"] :
        [Bundle() imageForResource:@"AlertStopBig"];
    self.appIcon.image = NSApp.applicationIconImage;
    self.pathLabel.stringValue = m_Path ? m_Path : @"";
    self.errorLabel.stringValue = m_Error ? m_Error : @"";
    self.messageLabel.stringValue = m_Message ? m_Message : @"";
    [self.window recalculateKeyViewLoop];
    NSBeep();
}

- (void)placeButtons
{
    if( m_Buttons.empty() ) {
        auto title = NSLocalizedString(@"Close", "");
        m_Buttons.emplace_back(std::make_pair(title, m_EscapeButtonResponse));
    }

    NSButton *last = nil;
    const auto content_view = self.window.contentView;
    for( auto p: m_Buttons ) {
        NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        button.translatesAutoresizingMaskIntoConstraints = false;
        button.buttonType = NSButtonTypeMomentaryPushIn;
        button.bezelStyle = NSBezelStyleRounded;
        button.tag = p.second;
        button.title = p.first;
        button.target = self;
        button.action = @selector(onButtonClick:);
        button.keyEquivalent = !last ? @"\r" : @"";
        [content_view addSubview:button];
        
        if( last ) {
            NSDictionary *views = NSDictionaryOfVariableBindings(button, last);
            [content_view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                @"[button(>=80)]-[last]" options:0 metrics:nil views:views]];
            [content_view addConstraint:[NSLayoutConstraint
                                         constraintWithItem:button
                                         attribute:NSLayoutAttributeCenterY
                                         relatedBy:NSLayoutRelationEqual
                                         toItem:last
                                         attribute:NSLayoutAttributeCenterY
                                         multiplier:1
                                         constant:0]];
        }
        else {
            const auto bottom = m_ShowApplyToAll ? self.applyToAllCheckBox : self.errorLabel;
            NSDictionary *views = NSDictionaryOfVariableBindings(button, bottom);
            [content_view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                @"[button(>=80)]-|" options:0 metrics:nil views:views]];
            [content_view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                @"V:[bottom]-(==16)-[button]-|" options:0 metrics:nil views:views]];
            self.window.initialFirstResponder = button;
        }
        last = button;
    }
    NSDictionary *views = NSDictionaryOfVariableBindings(last);
    [content_view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                                             @"|-(>=20)-[last]" options:0 metrics:nil views:views]];
}

- (void)onButtonClick:(id)sender
{
    if( auto b = objc_cast<NSButton>(sender) ) {
        if( m_ShowApplyToAll && m_Context )
            m_Context->messages["apply_to_all"] = self.applyToAllCheckBox.state == NSOnState;
        [self.window.sheetParent endSheet:self.window returnCode:b.tag];
    }
}

- (void) setStyle:(GenericErrorDialogStyle)style
{
    m_Style = style;
}

- (GenericErrorDialogStyle)style
{
    return m_Style;
}

- (void) setErrorNo:(int)errorNo
{
    self.error = VFSError::ToNSError(errorNo).localizedDescription;
}

- (int) errorNo
{
    return m_ErrorNo;
}

- (void) addButtonWithTitle:(NSString*)_title responseCode:(NSModalResponse)_response
{
    m_Buttons.emplace_back(std::make_pair(_title, _response));
}

- (void)moveRight:(id)sender
{
    [self.window selectNextKeyView:sender];
}

- (void)moveLeft:(id)sender
{
    [self.window selectPreviousKeyView:sender];
}

- (void) addAbortButton
{
    auto title = NSLocalizedString(@"Abort", "");
    [self addButtonWithTitle:title responseCode:nc::ops::NSModalResponseStop];
}

- (void) addSkipButton
{
    auto title = NSLocalizedString(@"Skip", "");
    [self addButtonWithTitle:title responseCode:nc::ops::NSModalResponseSkip];
}

- (void) addSkipAllButton
{
    auto title = NSLocalizedString(@"Skip All", "");
    [self addButtonWithTitle:title responseCode:nc::ops::NSModalResponseSkipAll];
}

@end

@interface NCOpsGenericErrorDialogWindow : NSWindow
@end

@implementation NCOpsGenericErrorDialogWindow
- (void)cancelOperation:(id)sender
{
    const auto response = ((NCOpsGenericErrorDialog*)(self.windowController)).escapeButtonResponse;
    [self.sheetParent endSheet:self returnCode:response];
}

@end
