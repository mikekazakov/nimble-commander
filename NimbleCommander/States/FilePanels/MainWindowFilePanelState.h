//
//  MainWindowFilePanelState.h
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <VFS/VFS.h>
#import <MMTabBarView/MMTabBarView.h>
#include "../MainWindowStateProtocol.h"
#include "../../Bootstrap/Config.h"
//#include "rapidjson.h"

class PanelData;
class ExternalToolsStorage;
@class Operation;
@class PanelView;
@class PanelController;
@class OperationsController;
@class QuickLookView;
@class BriefSystemOverview;
@class FilePanelMainSplitView;
@class MainWndGoToButton;
@class OperationsSummaryViewController;
@class FilePanelOverlappedTerminal;
@class MainWindowFilePanelsStateToolbarDelegate;
@class ColoredSeparatorLine;

struct MainWindowFilePanelState_OverlappedTerminalSupport;

@interface MainWindowFilePanelState : NSView<MainWindowStateProtocol, MMTabBarViewDelegate>
{
    vector<PanelController*> m_LeftPanelControllers;
    vector<PanelController*> m_RightPanelControllers;
    __weak PanelController*  m_LastFocusedPanelController;
    
    FilePanelMainSplitView *m_MainSplitView;
    NSLayoutConstraint     *m_MainSplitViewBottomConstraint;

    unique_ptr<MainWindowFilePanelState_OverlappedTerminalSupport> m_OverlappedTerminal;
    
    OperationsController *m_OperationsController;
    OperationsSummaryViewController *m_OpSummaryController;
    
    ColoredSeparatorLine *m_SeparatorLine;
    MainWindowFilePanelsStateToolbarDelegate *m_ToolbarDelegate;
    __weak NSResponder   *m_LastResponder;
    
    bool                m_ShowTabs;
    bool                m_GoToForceActivation;
    
    vector<GenericConfig::ObservationTicket> m_ConfigObservationTickets;
}

@property (nonatomic, readonly) ExternalToolsStorage &externalToolsStorage;
@property (nonatomic, readonly) OperationsController *OperationsController;
@property (nonatomic, readonly) OperationsSummaryViewController *operationsSummaryView;
@property (nonatomic, readonly) bool isPanelActive;

- (id) initWithFrame:(NSRect)frameRect Window:(NSWindow*)_wnd;
- (void)ActivatePanelByController:(PanelController *)controller;
- (void)activePanelChangedTo:(PanelController *)controller;

/**
 * Called by panel controller when it sucessfuly changes it's current path
 */
- (void)PanelPathChanged:(PanelController*)_panel;
- (void)revealEntries:(const vector<string>&)_filenames inDirectory:(const string&)_path;

@property (readonly) vector< tuple<string,VFSHostPtr> > filePanelsCurrentPaths; // result may contain duplicates


- (QuickLookView*)RequestQuickLookView:(PanelController*)_panel;
- (BriefSystemOverview*)RequestBriefSystemOverview:(PanelController*)_panel;
- (void)requestTerminalExecution:(const string&)_filename at:(const string&)_cwd;
- (void)CloseOverlay:(PanelController*)_panel;


- (void) AddOperation:(Operation*)_operation;

- (optional<rapidjson::StandaloneValue>) encodeRestorableState;
- (void) decodeRestorableState:(const rapidjson::StandaloneValue&)_state;
- (void) markRestorableStateAsInvalid;

/**
 * Return currently active file panel if any.
 */
@property (nonatomic, readonly) PanelController *activePanelController;
@property (nonatomic, readonly) PanelData       *activePanelData; // based on .ActivePanelController
@property (nonatomic, readonly) PanelView       *activePanelView; // based on .ActivePanelController

/**
 * If current active panel controller is left - return .rightPanelController,
 * If current active panel controller is right - return .leftPanelController,
 * If there's no active panel controller (no focus) - return nil
 * (regardless if this panel is collapsed or overlayed)
 */
@property (nonatomic, readonly) PanelController *oppositePanelController;
@property (nonatomic, readonly) PanelData       *oppositePanelData; // based on oppositePanelController
@property (nonatomic, readonly) PanelView       *oppositePanelView; // based on oppositePanelController

/**
 * Pick one of a controllers in left side tabbed bar, which is currently selected (regardless if it is active or not).
 * May return nil in init/shutdown period or in invalid state.
 */
@property (nonatomic, readonly) PanelController *leftPanelController;

/**
 * Pick one of a controllers in right side tabbed bar, which is currently selected (regardless if it is active or not).
 * May return nil in init/shutdown period or in invalid state.
 */
@property (nonatomic, readonly) PanelController *rightPanelController;

/**
 * Checks if this controller is one of a state's left-side controllers set.
 */
- (bool) isLeftController:(PanelController*)_controller;

/**
 * Checks if this controller is one of a state's right-side controllers set.
 */
- (bool) isRightController:(PanelController*)_controller;

/**
 * Panels split view may be hidden to fully show overlapped terminal contents
 */
@property (nonatomic, readonly) bool isPanelsSplitViewHidden;

@property (nonatomic, readonly) bool anyPanelCollapsed;

- (void) HandleTabButton;

// UI wiring
- (IBAction)onLeftPanelGoToButtonAction:(id)sender;
- (IBAction)onRightPanelGoToButtonAction:(id)sender;

@end


@interface MainWindowFilePanelState ()

- (void)updateBottomConstraint;

- (void)addNewControllerOnLeftPane:(PanelController*)_pc;
- (void)addNewControllerOnRightPane:(PanelController*)_pc;


@property (strong) IBOutlet NSToolbar *filePanelsToolsbar;

@end


#import "MainWindowFilePanelState+ContextMenu.h"
#import "MainWindowFilePanelState+Menu.h"
#import "MainWindowFilePanelState+TabsSupport.h"
#import "MainWindowFilePanelState+OverlappedTerminalSupport.h"
#import "MainWindowFilePanelState+Tools.h"

