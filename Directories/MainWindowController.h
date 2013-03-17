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

@interface MainWindowController : NSWindowController

enum ActiveState
{
    StateLeftPanel,
    StateRightPanel
    // many more will be here
};

// NIB outlets
@property (strong) IBOutlet PanelView *LeftPanelView;
@property (strong) IBOutlet PanelView *RightPanelView;
@property (strong) IBOutlet JobView *JobView;
@property (strong) IBOutlet MainWndGoToButton *LeftPanelGoToButton;
@property (strong) IBOutlet MainWndGoToButton *RightPanelGoToButton;

// NIB actions
- (IBAction)LeftPanelGoToButtonAction:(id)sender;
- (IBAction)RightPanelGoToButtonAction:(id)sender;


// this method will be called by App in all MainWindowControllers with same params
- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long)_ticket;

@end
