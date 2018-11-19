// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include "TrialWindowController.h"

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
        m_Self = self;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
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
    
    GA().PostScreenView("Trial Nag Screen");
}

- (IBAction)OnClose:(id)sender
{
    [self.window close];
}

- (IBAction)OnBuy:(id)sender
{
    auto handler = self.onBuyLicense;
    if( handler != nullptr )
        handler();
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
    [self.window makeKeyAndOrderFront:self];
    [self.window makeMainWindow];
}

@end
