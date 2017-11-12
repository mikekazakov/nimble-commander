// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#import <MMTabBarView/MMTabBarView.h>
#include "../MainWindowStateProtocol.h"
#include "../../Bootstrap/Config.h"

namespace nc::ops {
    class Pool;
}
namespace nc::panel::data {
    class Model;
}

class ExternalToolsStorage;
@class MainWindowController;
@class Operation;
@class PanelView;
@class PanelController;
@class QuickLookView;
@class BriefSystemOverview;
@class FilePanelMainSplitView;
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
    
    ColoredSeparatorLine *m_SeparatorLine;
    MainWindowFilePanelsStateToolbarDelegate *m_ToolbarDelegate;
    __weak NSResponder   *m_LastResponder;
    
    bool                m_ShowTabs;
    
    vector<GenericConfig::ObservationTicket> m_ConfigTickets;
    shared_ptr<nc::ops::Pool> m_OperationsPool;
}

@property (nonatomic, readonly) MainWindowController* mainWindowController;
@property (nonatomic, readonly) ExternalToolsStorage &externalToolsStorage;
@property (nonatomic, readonly) nc::ops::Pool& operationsPool;
@property (nonatomic, readonly) bool isPanelActive;
@property (nonatomic, readonly) bool goToForcesPanelActivation;

- (instancetype) initDefaultFileStateWithFrame:(NSRect)frameRect andPool:(nc::ops::Pool&)_pool;
- (instancetype) initEmptyFileStateWithFrame:(NSRect)frameRect andPool:(nc::ops::Pool&)_pool;

- (void) loadDefaultPanelContent;


- (void)ActivatePanelByController:(PanelController *)controller;
- (void)activePanelChangedTo:(PanelController *)controller;


/**
 * Ensures that this panel is not collapsed and is not overlaid.
 */
- (void)revealPanel:(PanelController *)panel;

/**
 * Called by panel controller when it sucessfuly changes it's current path
 */
- (void)PanelPathChanged:(PanelController*)_panel;
- (void)revealEntries:(const vector<string>&)_filenames inDirectory:(const string&)_path;

@property (nonatomic, readonly) vector< tuple<string,VFSHostPtr> > filePanelsCurrentPaths; // result may contain duplicates


- (QuickLookView*)RequestQuickLookView:(PanelController*)_panel;
- (BriefSystemOverview*)RequestBriefSystemOverview:(PanelController*)_panel;
- (void)requestTerminalExecution:(const string&)_filename at:(const string&)_cwd;
- (void)CloseOverlay:(PanelController*)_panel;

- (optional<rapidjson::StandaloneValue>) encodeRestorableState;
- (bool) decodeRestorableState:(const rapidjson::StandaloneValue&)_state;
- (void) markRestorableStateAsInvalid;

- (void) saveDefaultInitialState;

/**
 * Return currently active file panel if any.
 */
@property (nonatomic, readonly) PanelController *activePanelController;
@property (nonatomic, readonly) const nc::panel::data::Model *activePanelData; // based on .ActivePanelController
@property (nonatomic, readonly) PanelView       *activePanelView; // based on .ActivePanelController

/**
 * If current active panel controller is left - return .rightPanelController,
 * If current active panel controller is right - return .leftPanelController,
 * If there's no active panel controller (no focus) - return nil
 * (regardless if this panel is collapsed or overlayed)
 */
@property (nonatomic, readonly) PanelController *oppositePanelController;
@property (nonatomic, readonly) const nc::panel::data::Model *oppositePanelData; // based on oppositePanelController
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

@property (nonatomic, readonly) bool bothPanelsAreVisible;

/**
 * Process Tab button - change focus from left panel to right and vice versa.
 */
- (void) changeFocusedSide;

@end


@interface MainWindowFilePanelState ()

- (void)updateBottomConstraint;

- (void)addNewControllerOnLeftPane:(PanelController*)_pc;
- (void)addNewControllerOnRightPane:(PanelController*)_pc;


@property (nonatomic) IBOutlet NSToolbar *filePanelsToolsbar;

@end

#import "MainWindowFilePanelState+Menu.h"
#import "MainWindowFilePanelState+TabsSupport.h"
#import "MainWindowFilePanelState+OverlappedTerminalSupport.h"
#import "MainWindowFilePanelState+Tools.h"

