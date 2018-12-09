// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#import <MMTabBarView/MMTabBarView.h>
#include "../MainWindowStateProtocol.h"
#include <Config/Config.h>
#include "PanelViewKeystrokeSink.h"
#include "PanelPreview.h"
#include "PanelControllerPersistency.h"
#include <Utility/MIMResponder.h>

namespace nc::ops {
    class Pool;
}

namespace nc::panel {
    class FavoriteLocationsStorage;
    class ClosedPanelsHistory;
    namespace data {
        class Model;
    }
}

class ExternalToolsStorage;
@class NCMainWindowController;
@class Operation;
@class PanelView;
@class PanelController;
@class BriefSystemOverview;
@class FilePanelMainSplitView;
@class FilePanelOverlappedTerminal;
@class MainWindowFilePanelsStateToolbarDelegate;
@class ColoredSeparatorLine;

struct MainWindowFilePanelState_OverlappedTerminalSupport;

@interface MainWindowFilePanelState : NSView<NCMainWindowState,
                                             NCPanelViewKeystrokeSink,
                                             MMTabBarViewDelegate>
{
    std::function<PanelController*()> m_PanelFactory;
    std::vector<PanelController*> m_LeftPanelControllers;
    std::vector<PanelController*> m_RightPanelControllers;
    __weak PanelController*  m_LastFocusedPanelController;
    
    AttachedResponder *m_AttachedResponder;
    
    FilePanelMainSplitView *m_SplitView;
    NSLayoutConstraint     *m_MainSplitViewBottomConstraint;

    std::unique_ptr<MainWindowFilePanelState_OverlappedTerminalSupport> m_OverlappedTerminal;
    
    ColoredSeparatorLine *m_SeparatorLine;
    MainWindowFilePanelsStateToolbarDelegate *m_ToolbarDelegate;
    __weak NSResponder   *m_LastResponder;
    
    bool                m_ShowTabs;
    
    std::vector<nc::config::Token> m_ConfigTickets;
    std::shared_ptr<nc::ops::Pool> m_OperationsPool;
    std::shared_ptr<nc::panel::ClosedPanelsHistory> m_ClosedPanelsHistory;
    std::shared_ptr<nc::panel::FavoriteLocationsStorage> m_FavoriteLocationsStorage;
    nc::panel::ControllerStateJSONDecoder *m_ControllerStateJSONDecoder;    
}

@property (nonatomic, readonly) NCMainWindowController* mainWindowController;
@property (nonatomic, readonly) FilePanelMainSplitView *splitView;
@property (nonatomic, readonly) ExternalToolsStorage &externalToolsStorage;
@property (nonatomic, readonly) nc::ops::Pool& operationsPool;
@property (nonatomic, readonly) bool isPanelActive;
@property (nonatomic, readonly) bool goToForcesPanelActivation;
@property (nonatomic, readwrite)
    std::shared_ptr<nc::panel::ClosedPanelsHistory> closedPanelsHistory;
@property (nonatomic, readwrite)
    std::shared_ptr<nc::panel::FavoriteLocationsStorage> favoriteLocationsStorage;
@property (nonatomic, readwrite) AttachedResponder *attachedResponder;

- (instancetype) initWithFrame:(NSRect)frameRect
                       andPool:(nc::ops::Pool&)_pool
            loadDefaultContent:(bool)_load_content
                  panelFactory:(std::function<PanelController*()>)_panel_factory
    controllerStateJSONDecoder:(nc::panel::ControllerStateJSONDecoder&)_controller_json_decoder;

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

/**
 * result may contain duplicates
 */
@property (nonatomic, readonly)
    std::vector< std::tuple<std::string,VFSHostPtr> > filePanelsCurrentPaths;


- (id<NCPanelPreview>)quickLookForPanel:(PanelController*)_panel make:(bool)_make_if_absent;
- (BriefSystemOverview*)briefSystemOverviewForPanel:(PanelController*)_panel make:(bool)_make_if_absent;

- (void)requestTerminalExecution:(const std::string&)_filename
                              at:(const std::string&)_cwd;
- (void)closeAttachedUI:(PanelController*)_panel;

- (nc::config::Value) encodeRestorableState;
- (bool) decodeRestorableState:(const nc::config::Value&)_state;
- (void) markRestorableStateAsInvalid;

- (void) saveDefaultInitialState;

- (void) swapPanels;

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
@property (nonatomic, readonly) const std::vector<PanelController*> &leftControllers;

/**
 * Pick one of a controllers in right side tabbed bar, which is currently selected (regardless if it is active or not).
 * May return nil in init/shutdown period or in invalid state.
 */
@property (nonatomic, readonly) PanelController *rightPanelController;
@property (nonatomic, readonly) const std::vector<PanelController*> &rightControllers;

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
- (void)panelWillBeClosed:(PanelController*)_pc;

- (void)attachPanel:(PanelController*)_pc; // +detach in the future


@property (nonatomic) IBOutlet NSToolbar *filePanelsToolsbar;

@end
