// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include "TrialWindowController.h"
#include <Habanero/dispatch_cpp.h>

using namespace std::literals;

@interface TrialWindow : NSWindow
@end
@implementation TrialWindow
- (BOOL) canBecomeKeyWindow
{
    return true;
}

- (BOOL) canBecomeMainWindow
{
    return true;
}
@end


@interface TrialWindowController ()

@property (nonatomic) IBOutlet NSTextField *versionTextField;
@property (nonatomic) IBOutlet NSTextView *messageTextView;
@property (nonatomic) IBOutlet NSButton *okButton;

@end

@implementation TrialWindowController
{
    id m_Self;
}

- (id)init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self) {
        self.window.delegate = self;
        self.window.movableByWindowBackground = true;
        self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
        self.window.backgroundColor = NSColor.textBackgroundColor;
        m_Self = self;
        GA().PostScreenView("Trial Nag Screen");
    }
    return self;
}

- (void) setupControls
{
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
        self.okButton.title = self.okButton.alternateTitle;
    }
}

- (IBAction)OnClose:(id)sender
{
    if( self.isExpired ) {
        auto handler = self.onQuit;
        if( handler != nullptr )
            handler();
    }
    [self.window close];
}

- (IBAction)OnBuy:(id)sender
{
    auto handler = self.onBuyLicense;
    if( handler != nullptr )
        handler();
}

- (IBAction)OnActivate:(id)sender
{
    auto handler = self.onActivate;
    if( handler != nullptr ) {
        const auto activated = handler();
        if( activated == true ) {
            dispatch_to_main_queue_after(200ms, [=]{
                [self.window close];
            });
        }
    }
}

- (void)windowWillClose:(NSNotification *)notification
{
    self.window.delegate = nil;    
    dispatch_to_main_queue_after(10ms, [=]{
        m_Self = nil;
    });
}

- (void) show
{
    [self setupControls];
    [self.window makeKeyAndOrderFront:self];
    [self.window makeMainWindow];
}

@end
