// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
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
        self.window.backgroundColor = NSColor.whiteColor;
        self.window.movableByWindowBackground = true;
        self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
        m_Self = self;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    NSString *html = [@"<style>body { font-family: Helvetica; font-size: 10pt }</style>" stringByAppendingString:
                      NSLocalizedString(@"__TRIAL_WINDOW_NOTE", "Nag screen text about test period")];
    self.messageTextView.textStorage.attributedString = [[NSAttributedString alloc] initWithHTML:[html dataUsingEncoding:NSUTF8StringEncoding]
                                                                                         options:@{ NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding) }
                                                                              documentAttributes:nil];
    self.messageTextView.textContainer.lineFragmentPadding = 0;
    
    self.versionTextField.stringValue = [NSString stringWithFormat:@"Version %@ (%@)\n%@",
                                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"],
                                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleVersion"],
                                         [NSBundle.mainBundle.infoDictionary objectForKey:@"NSHumanReadableCopyright"]
                                         ];
    
    GA().PostScreenView("Trial Nag Screen");
}

- (IBAction)OnClose:(id)sender
{
    [self.window close];
}

- (void)windowWillClose:(NSNotification *)notification
{
    self.window.delegate = nil;    
    dispatch_to_main_queue_after(10ms, [=]{
        m_Self = nil;
    });
}

- (void) doShow
{
    [self.window makeKeyAndOrderFront:self];
    [self.window makeMainWindow];
}

+ (void) showTrialWindow
{
    [[[TrialWindowController alloc] init] doShow];
}

@end
