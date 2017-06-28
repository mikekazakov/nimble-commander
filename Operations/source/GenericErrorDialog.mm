#include "GenericErrorDialog.h"
#include <VFS/VFS.h>
#include "Internal.h"

using namespace nc::ops;

@interface NCOpsGenericErrorDialog ()
@property (strong) IBOutlet NSTextField *pathLabel;
@property (strong) IBOutlet NSTextField *errorLabel;
@property (strong) IBOutlet NSTextField *messageLabel;
@property (strong) IBOutlet NSImageView *appIcon;
@property (strong) IBOutlet NSImageView *dialogIcon;

@end

@implementation NCOpsGenericErrorDialog
{
    GenericErrorDialogStyle m_Style;
    NSModalResponse m_EscapeButtonResponse;
    NSString* m_Message;
    NSString* m_Path;
    NSString* m_Error;
    int m_ErrorNo;
    vector<pair<NSString*,NSModalResponse>> m_Buttons;
}

@synthesize escapeButtonResponse = m_EscapeButtonResponse;
@synthesize message = m_Message;
@synthesize path = m_Path;
@synthesize error = m_Error;

- (instancetype)init
{
    self = [super initWithWindowNibName:@"GenericErrorDialog"];
    if( self ) {
        m_Style = GenericErrorDialogStyle::Caution;
        m_EscapeButtonResponse = NSModalResponseCancel;
        m_ErrorNo = VFSError::Ok;
    
    }
    return self;
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
    if( m_Buttons.empty() )
        m_Buttons.emplace_back(make_pair(@"Close", m_EscapeButtonResponse));

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
            const auto error = self.errorLabel;
            NSDictionary *views = NSDictionaryOfVariableBindings(button, error);
            [content_view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                @"[button(>=80)]-|" options:0 metrics:nil views:views]];
            [content_view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                @"V:[error]-(==16)-[button]-|" options:0 metrics:nil views:views]];
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
    if( auto b = objc_cast<NSButton>(sender) )
        [self.window.sheetParent endSheet:self.window returnCode:b.tag];
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
    m_Buttons.emplace_back(make_pair(_title, _response));
}

- (void)moveRight:(id)sender
{
    [self.window selectNextKeyView:sender];
}

- (void)moveLeft:(id)sender
{
    [self.window selectPreviousKeyView:sender];
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
