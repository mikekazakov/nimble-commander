// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/SimpleComboBoxPersistentDataSource.h>
#include "SpotlightSearchPopupViewController.h"

static const auto g_ConfigHistoryPath = "filePanel.findWithSpotlightPopup.queries";

@interface SpotlightSearchPopupViewController ()

@property (nonatomic) IBOutlet NSComboBox *queryComboBox;

@end

@implementation SpotlightSearchPopupViewController
{
    SimpleComboBoxPersistentDataSource *m_QueryHistory;
    std::function<void(const std::string&)> m_Handler;
}

@synthesize handler = m_Handler;

- (void)viewDidLoad
{
    [super viewDidLoad];

    m_QueryHistory = [[SimpleComboBoxPersistentDataSource alloc] initWithStateConfigPath:g_ConfigHistoryPath];
    self.queryComboBox.usesDataSource = true;
    self.queryComboBox.dataSource = m_QueryHistory;
    
    GA().PostScreenView("Spotlight Popup");
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
