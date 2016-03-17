//
//  TrialWindowController.m
//  Files
//
//  Created by Michael G. Kazakov on 27/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

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


@implementation TrialWindowController
{
    id m_Self;
}

- (id)init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if(self) {
        (void)self.window;
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
    
    NSString *s1 = @"This is a trial version of Files manager.\nAfter a period of one month you must have\na ";
    [string appendAttributedString:[[NSMutableAttributedString alloc] initWithString:s1]];
    
    NSURL* url = [NSURL URLWithString:@"https://itunes.apple.com/app/files-pro/id942443942?ls=1&mt=12"];
    [string appendAttributedString:[self hyperlinkFromString:@"version from App Store" withURL:url]];
    
    NSString *s2 = @" installed on your hard drive or delete Files manager from this computer.\n\nThis window appears only in trial version.";
    [string appendAttributedString:[[NSMutableAttributedString alloc] initWithString:s2]];
        
    [self.messageTextView.textStorage setAttributedString: string];
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

- (id) hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL
{
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString: inString];
    NSRange range = NSMakeRange(0, [attrString length]);
    
    [attrString beginEditing];
    [attrString addAttribute:NSLinkAttributeName value:[aURL absoluteString] range:range];
    
    // make the text appear in blue
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
    
    // next make the text appear with an underline
    [attrString addAttribute:
     NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
    
    [attrString endEditing];
    
    return attrString;
}

@end
