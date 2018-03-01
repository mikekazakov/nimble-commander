// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/AppStoreHelper.h>
#include "ProFeaturesWindowController.h"

@interface ProFeaturesWindowController ()
@property (nonatomic) IBOutlet NSTextView *learnMoreURL;
@property (nonatomic) IBOutlet NSTextField *priceLabel;
@property (nonatomic) IBOutlet NSButton *dontShowAgainCheckbox;

@end

@implementation ProFeaturesWindowController
{
    bool    m_DontShowAgain;
}

@synthesize suppressDontShowAgain;
@synthesize dontShowAgain = m_DontShowAgain;

- (id) init
{
    self = [super initWithWindowNibName:NSStringFromClass(self.class)];
    if( self ) {
        m_DontShowAgain = false;
        self.suppressDontShowAgain = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.learnMoreURL.textStorage.mutableString.string = NSLocalizedString(@"Learn more about advanced tools", "IAP dialog text for URL pointing to website");
    [self.learnMoreURL.textStorage addAttributes:@{NSLinkAttributeName: @"http://magnumbytes.com/"}
                                           range:NSMakeRange(0, self.learnMoreURL.textStorage.length)];
    self.learnMoreURL.linkTextAttributes = @{NSForegroundColorAttributeName: NSColor.blackColor,
                                             NSUnderlineStyleAttributeName: @1,
                                             NSCursorAttributeName:NSCursor.pointingHandCursor};
    
    self.priceLabel.stringValue = NCAppDelegate.me.appStoreHelper.priceString;
    self.dontShowAgainCheckbox.hidden = self.suppressDontShowAgain;
}

- (IBAction)onBuyNow:(id)sender
{
    m_DontShowAgain = (self.dontShowAgainCheckbox.state == NSOnState);    
    [NSApplication.sharedApplication stopModalWithCode:NSModalResponseOK];
}

- (IBAction)onContinue:(id)sender
{
    m_DontShowAgain = (self.dontShowAgainCheckbox.state == NSOnState);
    [NSApplication.sharedApplication stopModalWithCode:NSModalResponseCancel];
}

- (void)windowWillClose:(NSNotification *)notification
{
    m_DontShowAgain = (self.dontShowAgainCheckbox.state == NSOnState);
    [NSApplication.sharedApplication stopModalWithCode:NSModalResponseCancel];
}

@end
