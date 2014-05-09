//
//  MainWindowFilePanelState.h
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MainWindowStateProtocol.h"
#import "chained_strings.h"

class PanelData;
@class Operation;
@class PanelView;
@class PanelController;
@class OperationsController;
@class QuickLookView;
@class BriefSystemOverview;
@class FilePanelMainSplitView;
@class MainWndGoToButton;
@class OperationsSummaryViewController;
@class MyToolbar;

enum ActiveState
{
    StateLeftPanel,
    StateRightPanel
    // many more will be here
};

@interface MainWindowFilePanelState : NSView<MainWindowStateProtocol>
{
    ApplicationSkin m_Skin;

    ActiveState m_ActiveState;
    
    PanelController *m_LeftPanelController;     // creates and owns
    PanelController *m_RightPanelController;    // creates and owns
    
    FilePanelMainSplitView *m_MainSplitView;
    
    MainWndGoToButton *m_LeftPanelGoToButton;
    MainWndGoToButton *m_RightPanelGoToButton;
    
    NSProgressIndicator *m_LeftPanelSpinningIndicator;
    NSProgressIndicator *m_RightPanelSpinningIndicator;
    NSButton            *m_LeftPanelShareButton;
    NSButton            *m_RightPanelShareButton;
    OperationsController *m_OperationsController;
    OperationsSummaryViewController *m_OpSummaryController;
    
    NSBox                *m_SeparatorLine;
    MyToolbar            *m_Toolbar;
}


@property OperationsController *OperationsController;

- (id) initWithFrame:(NSRect)frameRect Window:(NSWindow*)_wnd;
- (void)ActivatePanelByController:(PanelController *)controller;

- (void)PanelPathChanged:(PanelController*)_panel;
- (void)RevealEntries:(chained_strings)_entries inPath:(const char*)_path;

- (void)GetFilePanelsGlobalPaths:(vector<string> &)_paths;


- (QuickLookView*)RequestQuickLookView:(PanelController*)_panel;
- (BriefSystemOverview*)RequestBriefSystemOverview:(PanelController*)_panel;
- (void)CloseOverlay:(PanelController*)_panel;


- (void) AddOperation:(Operation*)_operation;



- (PanelData*) ActivePanelData;
- (PanelController*) ActivePanelController;
- (PanelView*) ActivePanelView;


- (IBAction)OnDeleteCommand:(id)sender;
@end

#import "MainWindowFilePanelState+ContextMenu.h"
#import "MainWindowFilePanelState+Menu.h"
