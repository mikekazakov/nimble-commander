//
//  TrialWindowController.m
//  Files
//
//  Created by Michael G. Kazakov on 27/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "TrialWindowController.h"
#include "GoogleAnalytics.h"

static NSAttributedString *HyperlinkFromString(NSString *_string, NSURL* _url)
{
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString:_string];
    NSRange range = NSMakeRange(0, attrString.length);
    
    [attrString beginEditing];
    
    // set url itself
    [attrString addAttribute:NSLinkAttributeName
                       value:_url.absoluteString
                       range:range];
    
    // make the text appear in blue
    [attrString addAttribute:NSForegroundColorAttributeName
                       value:NSColor.blueColor
                       range:range];
    
    // next make the text appear with an underline
    [attrString addAttribute:NSUnderlineStyleAttributeName
                       value:@(NSUnderlineStyleSingle)
                       range:range];
    
    [attrString endEditing];
    
    return attrString;
}

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

@property (strong) IBOutlet NSTextField *versionTextField;
@property (strong) IBOutlet NSTextView *messageTextView;
@property (strong) IBOutlet NSTextField *copyrightTextField;

- (IBAction)OnClose:(id)sender;

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
    self.versionTextField.stringValue = [NSString stringWithFormat:@"Version %@ (%@)",
                                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"],
                                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleVersion"]];
    self.copyrightTextField.stringValue = [NSBundle.mainBundle.infoDictionary objectForKey:@"NSHumanReadableCopyright"];
    
    NSMutableAttributedString* string = [[NSMutableAttributedString alloc] init];
    
    NSString *s1 = @"This is a trial version of Nimble Commander.\nAfter a period of one month you must have a ";
    [string appendAttributedString:[[NSMutableAttributedString alloc] initWithString:s1]];
    
    NSURL* url = [NSURL URLWithString:@"https://itunes.apple.com/app/files-pro/id942443942?ls=1&mt=12"];
    [string appendAttributedString:HyperlinkFromString(@"version from App Store", url)];
    
    NSString *s2 = @" installed on your hard drive or delete Nimble Commander from this computer.\n\nThis window appears only in trial version.";
    [string appendAttributedString:[[NSMutableAttributedString alloc] initWithString:s2]];
        
    self.messageTextView.textStorage.attributedString = string;
    
    GoogleAnalytics::Instance().PostScreenView("Trial Nag Screen");
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
