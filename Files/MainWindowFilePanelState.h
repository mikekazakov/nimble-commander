//
//  MainWindowFilePanelState.h
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "3rd_party/MMTabBarView/MMTabBarView/MMTabBarView.h"
#import "MainWindowStateProtocol.h"
#import "chained_strings.h"
#import "VFS.h"

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
@class FilePanelOverlappedTerminal;

@interface MainWindowFilePanelState : NSView<MainWindowStateProtocol, NSToolbarDelegate, MMTabBarViewDelegate>
{
    vector<PanelController*> m_LeftPanelControllers;
    vector<PanelController*> m_RightPanelControllers;
    
    FilePanelMainSplitView *m_MainSplitView;
    NSLayoutConstraint     *m_MainSplitViewBottomConstraint;

    // overlapped terminal support
    FilePanelOverlappedTerminal *m_OverlappedTerminal;
    int                     m_OverlappedTerminalBottomGap;
    __weak PanelController* m_PreviouslyFocusedPanelController;
    
    MainWndGoToButton *m_LeftPanelGoToButton;
    MainWndGoToButton *m_RightPanelGoToButton;
    
    NSProgressIndicator *m_LeftPanelSpinningIndicator;
    NSProgressIndicator *m_RightPanelSpinningIndicator;
    NSButton            *m_LeftPanelShareButton;
    NSButton            *m_RightPanelShareButton;
    OperationsController *m_OperationsController;
    OperationsSummaryViewController *m_OpSummaryController;
    
    NSBox                *m_SeparatorLine;
    NSToolbar            *m_Toolbar;
    NSResponder          *m_LastResponder;
    
    bool                m_ShowTabs;
    bool                m_GoToForceActivation;
}


@property OperationsController *OperationsController;
@property (nonatomic, readonly) bool isPanelActive;

- (id) initWithFrame:(NSRect)frameRect Window:(NSWindow*)_wnd;
- (void)ActivatePanelByController:(PanelController *)controller;
- (void)activePanelChangedTo:(PanelController *)controller;

- (void)PanelPathChanged:(PanelController*)_panel;
- (void)RevealEntries:(chained_strings)_entries inPath:(const string&)_path;

@property (readonly) vector< tuple<string,VFSHostPtr> > filePanelsCurrentPaths; // result may contain duplicates


- (QuickLookView*)RequestQuickLookView:(PanelController*)_panel;
- (BriefSystemOverview*)RequestBriefSystemOverview:(PanelController*)_panel;
- (void)CloseOverlay:(PanelController*)_panel;


- (void) AddOperation:(Operation*)_operation;


- (void) savePanelOptionsFor:(PanelController*)_pc;


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

- (void) HandleTabButton;
@end


@interface MainWindowFilePanelState ()

- (void)savePanelsOptions;
- (void)frameDidChange;

@end


#import "MainWindowFilePanelState+ContextMenu.h"
#import "MainWindowFilePanelState+Menu.h"
#import "MainWindowFilePanelState+TabsSupport.h"
#import "MainWindowFilePanelState+OverlappedTerminalSupport.h"

