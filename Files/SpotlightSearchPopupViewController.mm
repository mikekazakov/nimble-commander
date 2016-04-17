//
//  SpotlightSearchPopupViewController.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 4/15/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#include "SimpleComboBoxPersistentDataSource.h"
#include "SpotlightSearchPopupViewController.h"

static const auto g_ConfigHistoryPath = "filePanel.findWithSpotlightPopup.queries";

@interface SpotlightSearchPopupViewController ()

@property (strong) IBOutlet NSComboBox *queryComboBox;

@end

@implementation SpotlightSearchPopupViewController
{
    SimpleComboBoxPersistentDataSource *m_QueryHistory;
    function<void(const string&)> m_Handler;
}

@synthesize handler = m_Handler;

- (void)viewDidLoad
{
    [super viewDidLoad];

    m_QueryHistory = [[SimpleComboBoxPersistentDataSource alloc] initWithStateConfigPath:g_ConfigHistoryPath];
    self.queryComboBox.usesDataSource = true;
    self.queryComboBox.dataSource = m_QueryHistory;
}

- (IBAction)onQueryComboBox:(id)sender
{
    NSString *query = self.queryComboBox.stringValue;
    
    if( query == nil || query.length == 0 )
        return;
    
    [m_QueryHistory reportEnteredItem:query];

    if( m_Handler )
        m_Handler( query.UTF8String );
    
    [self.view.window performClose:nil];
}

- (void)popoverDidClose:(NSNotification *)notification
{
    ((NSPopover*)notification.object).contentViewController = nil; // here we are
}

@end
