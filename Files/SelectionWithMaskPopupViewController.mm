//
//  SelectionWithMaskPopupViewController.m
//  Files
//
//  Created by Michael G. Kazakov on 23/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "SelectionWithMaskPopupViewController.h"
#include "SimpleComboBoxPersistentDataSource.h"
#include "GoogleAnalytics.h"

static const auto                       g_ConfigHistoryPath = "filePanel.selectWithMaskPopup.masks";
static unordered_map<void*, NSString*>  g_InitialMask;
static spinlock                         g_InitialMaskLock;

@interface SelectionWithMaskPopupViewController()

@property (strong) IBOutlet NSComboBox *comboBox;
@property (strong) IBOutlet NSTextField *titleLabel;

@end

@implementation SelectionWithMaskPopupViewController
{
    void                               *m_TargetWnd;
    SimpleComboBoxPersistentDataSource *m_MaskHistory;
    function<void(NSString *mask)>      m_Handler;
    bool                                m_DoesSelect;
}

@synthesize handler = m_Handler;

- (instancetype) initForWindow:(NSWindow*)_wnd doesSelect:(bool)_select;
{
    self = [super init];
    if( self ) {
        m_TargetWnd = (__bridge void*)_wnd;
        m_DoesSelect = _select;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.titleLabel.stringValue = m_DoesSelect ?
        NSLocalizedString(@"Select files using mask:", "Title for selection with mask popup") :
        NSLocalizedString(@"Deselect files using mask:", "Title for deselection with mask popup");
    
    m_MaskHistory = [[SimpleComboBoxPersistentDataSource alloc] initWithStateConfigPath:g_ConfigHistoryPath];
    self.comboBox.usesDataSource = true;
    self.comboBox.dataSource = m_MaskHistory;
    
    LOCK_GUARD(g_InitialMaskLock) {
        auto i = g_InitialMask.find(m_TargetWnd);
        self.comboBox.stringValue = i != end(g_InitialMask) ? (*i).second : @"*.*";
    }
    
    GoogleAnalytics::Instance().PostScreenView("Mask Selection Popup");
}

- (IBAction)OnComboBox:(id)sender
{
    NSString *mask = self.comboBox.stringValue;
    if( mask == nil || mask.length == 0 )
        return;
    
    // exclude meaningless masks - don't store them
    if(!([mask isEqualToString:@""]    ||
         [mask isEqualToString:@"."]   ||
         [mask isEqualToString:@".."]  ||
         [mask isEqualToString:@"*"]   ||
         [mask isEqualToString:@"*.*"] ) )
        [m_MaskHistory reportEnteredItem:mask];
    
    LOCK_GUARD(g_InitialMaskLock)
        g_InitialMask[m_TargetWnd] = mask;
    
    if( m_Handler )
        m_Handler( mask );

    [self.view.window performClose:nil];
}

- (void)popoverDidClose:(NSNotification *)notification
{
    ((NSPopover*)notification.object).contentViewController = nil; // here we are
}

@end
