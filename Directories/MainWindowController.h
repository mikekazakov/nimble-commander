//
//  MainWindowController.h
//  Directories
//
//  Created by Michael G. Kazakov on 09.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "PanelView.h"
#include "PanelData.h"
#include "CopyAsSheetController.h"
#include "JobView.h"
#include "MainWndGoToButton.h"

@interface MainWindowController : NSWindowController <NSWindowDelegate>

enum ActiveState
{
    StateLeftPanel,
    StateRightPanel
    // many more will be here
};

// Window NIB outlets
@property (strong) IBOutlet JobView *JobView;
@property (strong) IBOutlet MainWndGoToButton *LeftPanelGoToButton;
@property (strong) IBOutlet MainWndGoToButton *RightPanelGoToButton;
@property (weak) IBOutlet NSView *OpSummaryBox;

// Window NIB actions
- (IBAction)LeftPanelGoToButtonAction:(id)sender;
- (IBAction)RightPanelGoToButtonAction:(id)sender;

// Menu and HK actions
- (IBAction)ToggleShortViewMode:(id)sender;
- (IBAction)ToggleMediumViewMode:(id)sender;
- (IBAction)ToggleFullViewMode:(id)sender;
- (IBAction)ToggleWideViewMode:(id)sender;
- (IBAction)ToggleSortByName:(id)sender;
- (IBAction)ToggleSortByExt:(id)sender;
- (IBAction)ToggleSortByMTime:(id)sender;
- (IBAction)ToggleSortBySize:(id)sender;
- (IBAction)ToggleSortByBTime:(id)sender;
- (IBAction)LeftPanelGoto:(id)sender;
- (IBAction)RightPanelGoto:(id)sender;
- (IBAction)OnSyncPanels:(id)sender;
- (IBAction)OnSwapPanels:(id)sender;
- (IBAction)OnRefreshPanel:(id)sender;
- (IBAction)OnFileAttributes:(id)sender;
- (IBAction)OnDetailedVolumeInformation:(id)sender;
- (IBAction)OnDeleteCommand:(id)sender;
- (IBAction)OnCreateDirectoryCommand:(id)sender;

// this method will be called by App in all MainWindowControllers with same params
- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long)_ticket;

@end
