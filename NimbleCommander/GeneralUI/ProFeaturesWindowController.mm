// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
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
        self.priceText = @"";
        self.suppressDontShowAgain = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    const auto msg = NSLocalizedString(@"Learn more about advanced tools",
                                 "IAP dialog text for URL pointing to website");
    const auto text_storage = self.learnMoreURL.textStorage; 
    text_storage.mutableString.string = msg; 
    [text_storage addAttributes:@{NSLinkAttributeName: @"http://magnumbytes.com/"}
                          range:NSMakeRange(0, text_storage.length)];
    self.learnMoreURL.linkTextAttributes = @{NSForegroundColorAttributeName: NSColor.textColor,
                                             NSUnderlineStyleAttributeName: @1,
                                             NSCursorAttributeName:NSCursor.pointingHandCursor};
    
    self.priceLabel.stringValue = self.priceText;
    self.dontShowAgainCheckbox.hidden = self.suppressDontShowAgain;
}

- (IBAction)onBuyNow:(id)[[maybe_unused]]sender
{
    m_DontShowAgain = (self.dontShowAgainCheckbox.state == NSOnState);
    [self.window close];
    [NSApplication.sharedApplication stopModalWithCode:NSModalResponseOK];    
}

- (IBAction)onContinue:(id)[[maybe_unused]]sender
{
    m_DontShowAgain = (self.dontShowAgainCheckbox.state == NSOnState);
    [self.window close];
    [NSApplication.sharedApplication stopModalWithCode:NSModalResponseCancel];    
}

@end
