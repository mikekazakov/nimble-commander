// Copyright (C) 2014-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TrialWindowController.h"
#include <Habanero/dispatch_cpp.h>

using namespace std::literals;

static const NSTimeInterval g_ForcedQuitInterval = 10. * 60.;

@interface TrialWindow : NSWindow
@end
@implementation TrialWindow
- (BOOL)canBecomeKeyWindow
{
    return true;
}

- (BOOL)canBecomeMainWindow
{
    return true;
}
@end

@interface TrialWindowController ()

@property(nonatomic) IBOutlet NSTextField *versionTextField;
@property(nonatomic) IBOutlet NSTextView *messageTextView;
@property(nonatomic) IBOutlet NSButton *okButton;

@end

@implementation TrialWindowController {
    id m_Self;
    NSTimer *m_SecondsTimer;
    NSTimeInterval m_SecondsTillForcedQuit;
    NSString *m_OkButtonAlternateTitle;
}

- (id)init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if( self ) {
        self.window.delegate = self;
        self.window.movableByWindowBackground = true;
        self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
        self.window.backgroundColor = NSColor.textBackgroundColor;
        m_Self = self;
        m_SecondsTillForcedQuit = g_ForcedQuitInterval;
    }
    return self;
}

- (void)setupControls
{
    m_OkButtonAlternateTitle = self.okButton.alternateTitle;

    auto text = NSLocalizedString(@"__TRIAL_WINDOW_NOTE", "Nag screen text about test period");
    auto text_storage = self.messageTextView.textStorage;
    [text_storage replaceCharactersInRange:NSMakeRange(0, text_storage.length) withString:text];
    self.messageTextView.textContainer.lineFragmentPadding = 0;

    auto info = NSBundle.mainBundle.infoDictionary;
    auto ver_fmt = NSLocalizedString(@"Version %@ (%@)\n%@", "Version info");
    auto version = [NSString stringWithFormat:ver_fmt,
                                              info[@"CFBundleShortVersionString"],
                                              info[@"CFBundleVersion"],
                                              info[@"NSHumanReadableCopyright"]];
    self.versionTextField.stringValue = version;

    if( self.isExpired ) {
        [self updateOkButtonTitle];
        __weak TrialWindowController *weak_self = self;
        m_SecondsTimer =
            [NSTimer scheduledTimerWithTimeInterval:1.0
                                            repeats:true
                                              block:^([[maybe_unused]] NSTimer *_Nonnull _timer) {
                                                if( TrialWindowController *strong_self = weak_self )
                                                    [strong_self secondsTick];
                                              }];
    }
}

- (IBAction)OnClose:(id) [[maybe_unused]] _sender
{
    if( self.isExpired ) {
        auto handler = self.onQuit;
        if( handler != nullptr )
            handler();
    }
    [self.window close];
}

- (IBAction)OnBuy:(id) [[maybe_unused]] _sender
{
    auto handler = self.onBuyLicense;
    if( handler != nullptr )
        handler();
}

- (IBAction)OnActivate:(id) [[maybe_unused]] _sender
{
    auto handler = self.onActivate;
    if( handler != nullptr ) {
        const auto activated = handler();
        if( activated == true ) {
            dispatch_to_main_queue_after(200ms, [=] { [self.window close]; });
        }
    }
}

- (void)windowWillClose:(NSNotification *) [[maybe_unused]] _notification
{
    self.window.delegate = nil;
    dispatch_to_main_queue_after(10ms, [=] { m_Self = nil; });
}

- (void)show
{
    [self setupControls];
    [self.window makeKeyAndOrderFront:self];
    [self.window makeMainWindow];
}

- (void)secondsTick
{
    m_SecondsTillForcedQuit -= 1.0;
    [self updateOkButtonTitle];
    if( m_SecondsTillForcedQuit <= 0. ) {
        [m_SecondsTimer invalidate];
        [self.okButton performClick:nil];
    }
}

- (void)updateOkButtonTitle
{
    NSDateComponentsFormatter *formatter = [NSDateComponentsFormatter new];
    formatter.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
    formatter.allowsFractionalUnits = false;
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorNone;
    const auto left_str = [formatter stringFromTimeInterval:m_SecondsTillForcedQuit];
    const auto full_str =
        [NSString stringWithFormat:@"%@ (%@)", m_OkButtonAlternateTitle, left_str];
    const auto attr_string = [[NSMutableAttributedString alloc] initWithString:full_str];
    const auto full_range = NSMakeRange(0, attr_string.length);
    const auto time_range = NSMakeRange(full_range.length - left_str.length - 1, left_str.length);
    const auto para_style = [NSMutableParagraphStyle new];
    para_style.alignment = self.okButton.alignment;
    const auto normal_attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:NSFont.systemFontSize],
        NSParagraphStyleAttributeName: para_style,
        NSForegroundColorAttributeName: NSColor.labelColor
    };
    const auto monospace_attributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:NSFont.systemFontSize
                                                              weight:NSFontWeightRegular],
        NSParagraphStyleAttributeName: para_style,
        NSForegroundColorAttributeName: NSColor.labelColor
    };
    [attr_string setAttributes:normal_attributes range:full_range];
    [attr_string setAttributes:monospace_attributes range:time_range];
    self.okButton.attributedTitle = attr_string;
}

@end
