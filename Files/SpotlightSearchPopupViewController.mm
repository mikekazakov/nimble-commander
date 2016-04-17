//
//  SpotlightSearchPopupViewController.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 4/15/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#include "SpotlightSearchPopupViewController.h"

@interface SpotlightSearchPopupViewController ()

@property (strong) IBOutlet NSComboBox *queryComboBox;

@end

@implementation SpotlightSearchPopupViewController
{
    function<void(const string&)> m_Handler;
}

@synthesize handler = m_Handler;

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (IBAction)onQueryComboBox:(id)sender
{
    if( self.queryComboBox.stringValue == nil || self.queryComboBox.stringValue.length == 0 )
        return;
    

    if( m_Handler )
        m_Handler( self.queryComboBox.stringValue.UTF8String );
    
    [self.view.window performClose:nil];
    
}

- (void)popoverDidClose:(NSNotification *)notification
{
    ((NSPopover*)notification.object).contentViewController = nil; // here we are
}

@end
