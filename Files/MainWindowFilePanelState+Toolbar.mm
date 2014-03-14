//
//  MainWindowFilePanelState+Toolbar.m
//  Files
//
//  Created by Michael G. Kazakov on 16.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState+Toolbar.h"
//#import "OperationsController.h"
#import "OperationsSummaryViewController.h"
#import "MainWndGoToButton.h"
#import "sysinfo.h"

@implementation MainWindowFilePanelState (Toolbar)

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
    if([itemIdentifier isEqualToString:@"filepanels_left_goto_button"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_LeftPanelGoToButton;
        return item;
    }
    
    if([itemIdentifier isEqualToString:@"filepanels_right_goto_button"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_RightPanelGoToButton;
        return item;
    }
    
    if([itemIdentifier isEqualToString:@"filepanels_left_share_button"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_LeftPanelShareButton;
        return item;
    }
    
    if([itemIdentifier isEqualToString:@"filepanels_right_share_button"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_RightPanelShareButton;
        return item;
    }
    
    if([itemIdentifier isEqualToString:@"filepanels_left_spinning_indicator"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_LeftPanelSpinningIndicator;
        return item;
    }
    
    if([itemIdentifier isEqualToString:@"filepanels_right_spinning_indicator"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_RightPanelSpinningIndicator;
        return item;
    }
    
    if([itemIdentifier isEqualToString:@"filepanels_operations_box"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_OpSummaryController.view;
        return item;
    }
    
    return nil;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_8)
        return @[ @"filepanels_left_goto_button",
                  @"filepanels_left_share_button",
                  @"filepanels_left_spinning_indicator",
                  NSToolbarFlexibleSpaceItemIdentifier,
                  @"filepanels_operations_box",
                  NSToolbarFlexibleSpaceItemIdentifier,
                  @"filepanels_right_spinning_indicator",
                  @"filepanels_right_share_button",
                  @"filepanels_right_goto_button"];
    else
        return @[ @"filepanels_left_goto_button",
                  @"filepanels_left_spinning_indicator",
                  NSToolbarFlexibleSpaceItemIdentifier,
                  @"filepanels_operations_box",
                  NSToolbarFlexibleSpaceItemIdentifier,
                  @"filepanels_right_spinning_indicator",
                  @"filepanels_right_goto_button"];
}

@end
