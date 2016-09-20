//
//  ProFeaturesWindowController.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 9/16/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#include "../../Files/AppDelegate.h"
#include "../../Files/AppStoreHelper.h"
#include "ProFeaturesWindowController.h"

@interface ProFeaturesWindowController ()
@property (strong) IBOutlet NSTextView *learnMoreURL;
@property (strong) IBOutlet NSTextField *priceLabel;
@property (strong) IBOutlet NSButton *dontShowAgainCheckbox;

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
    
    [self.learnMoreURL.textStorage addAttributes:@{NSLinkAttributeName: @"http://magnumbytes.com/"}
                                           range:NSMakeRange(0, self.learnMoreURL.textStorage.length)];
    self.learnMoreURL.linkTextAttributes = @{NSForegroundColorAttributeName: NSColor.blackColor,
                                             NSUnderlineStyleAttributeName: @1,
                                             NSCursorAttributeName:NSCursor.pointingHandCursor};
    
    self.priceLabel.stringValue = AppDelegate.me.appStoreHelper.priceString;
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
