// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/SimpleComboBoxPersistentDataSource.h>
#include "SelectionWithMaskPopupViewController.h"
#include <unordered_map>

static const auto                       g_ConfigHistoryPath = "filePanel.selectWithMaskPopup.masks";
static std::unordered_map<void*, NSString*> g_InitialMask;
static spinlock                         g_InitialMaskLock;

@interface SelectionWithMaskPopupViewController()

@property (nonatomic) IBOutlet NSComboBox *comboBox;
@property (nonatomic) IBOutlet NSTextField *titleLabel;

@end

@implementation SelectionWithMaskPopupViewController
{
    void                               *m_TargetWnd;
    SimpleComboBoxPersistentDataSource *m_MaskHistory;
    std::function<void(NSString *mask)> m_Handler;
    bool                                m_DoesSelect;
}

@synthesize handler = m_Handler;

- (instancetype) initForWindow:(NSWindow*)_wnd doesSelect:(bool)_select
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
        NSLocalizedString(@"Select files by mask:", "Title for selection by mask popup") :
        NSLocalizedString(@"Deselect files by mask:", "Title for deselection by mask popup");
    
    m_MaskHistory = [[SimpleComboBoxPersistentDataSource alloc] initWithStateConfigPath:g_ConfigHistoryPath];
    self.comboBox.usesDataSource = true;
    self.comboBox.dataSource = m_MaskHistory;
    
    LOCK_GUARD(g_InitialMaskLock) {
        auto i = g_InitialMask.find(m_TargetWnd);
        self.comboBox.stringValue = i != end(g_InitialMask) ? (*i).second : @"*.*";
    }
    
    GA().PostScreenView("Mask Selection Popup");
}

- (IBAction)OnComboBox:(id)[[maybe_unused]]_sender
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
