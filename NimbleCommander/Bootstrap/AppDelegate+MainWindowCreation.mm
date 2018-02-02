// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AppDelegate+MainWindowCreation.h"
#include "AppDelegate.Private.h"
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/States/MainWindow.h>
#include <NimbleCommander/States/FilePanels/MainWindowFilePanelState.h>
#include <NimbleCommander/States/FilePanels/PanelController.h>
#include <NimbleCommander/States/FilePanels/PanelView.h>
#include <NimbleCommander/States/FilePanels/PanelControllerActionsDispatcher.h>
#include <Operations/Pool.h>
#include <Operations/AggregateProgressTracker.h>
#include "Config.h"

static const auto g_ConfigRestoreLastWindowState = "filePanel.general.restoreLastWindowState";

namespace  {
    enum class CreationContext {
        Default,
        ManualRestoration,
        SystemRestoration
    };
}

static bool RestoreFilePanelStateFromLastOpenedWindow(MainWindowFilePanelState *_state);

@implementation NCAppDelegate(MainWindowCreation)

- (NCMainWindow*) allocateMainWindow
{
    auto window = [[NCMainWindow alloc] init];
    if( !window )
        return nil;
    window.restorationClass = self.class;
    return window;
}

- (PanelController*) allocatePanelController
{
    auto panel = [[PanelController alloc] initWithLayouts:self.panelLayouts
                                networkConnectionsManager:self.networkConnectionsManager
                                       vfsInstanceManager:self.vfsInstanceManager];
    
    auto actions_dispatcher = [[NCPanelControllerActionsDispatcher alloc] initWithController:panel];
    [panel setNextAttachedResponder:actions_dispatcher];
    [panel.view addKeystrokeSink:actions_dispatcher
                withBasePriority:nc::panel::view::BiddingPriority::Low];
    
    return panel;
}

static PanelController* PanelFactory()
{
    return [NCAppDelegate.me allocatePanelController];
}

- (MainWindowFilePanelState*)allocateFilePanelsWithFrame:(NSRect)_frame
                                               inContext:(CreationContext)_context
                                             withOpsPool:(nc::ops::Pool&)_operations_pool
{
    if( _context == CreationContext::Default ) {
        return [[MainWindowFilePanelState alloc] initWithFrame:_frame
                                                       andPool:_operations_pool
                                            loadDefaultContent:true
                                                  panelFactory:PanelFactory];
    }
    else if( _context == CreationContext::ManualRestoration ) {
        if( MainWindowController.canRestoreDefaultWindowStateFromLastOpenedWindow ) {
            auto state = [[MainWindowFilePanelState alloc] initWithFrame:_frame
                                                                 andPool:_operations_pool
                                                      loadDefaultContent:false
                                                            panelFactory:PanelFactory];
            RestoreFilePanelStateFromLastOpenedWindow(state);
            [state loadDefaultPanelContent];
            return state;
        }
        else if( GlobalConfig().GetBool(g_ConfigRestoreLastWindowState) ) {
            auto state = [[MainWindowFilePanelState alloc] initWithFrame:_frame
                                                                 andPool:_operations_pool
                                                      loadDefaultContent:false
                                                            panelFactory:PanelFactory];
            if( ![MainWindowController restoreDefaultWindowStateFromConfig:state] )
                [state loadDefaultPanelContent];
            return state;
        }
        else
            return [[MainWindowFilePanelState alloc] initWithFrame:_frame
                                                           andPool:_operations_pool
                                                loadDefaultContent:false
                                                      panelFactory:PanelFactory];
    }
    else if( _context == CreationContext::SystemRestoration ) {
        return [[MainWindowFilePanelState alloc] initWithFrame:_frame
                                                       andPool:_operations_pool
                                            loadDefaultContent:false
                                                  panelFactory:PanelFactory];
    }
    return nil;
}

- (MainWindowController*)allocateMainWindowInContext:(CreationContext)_context
{
    const auto window = [self allocateMainWindow];
    const auto frame = window.contentView.frame;
    const auto operations_pool =  nc::ops::Pool::Make();
    const auto window_controller = [[MainWindowController alloc] initWithWindow:window];
    window_controller.operationsPool = *operations_pool;
    self.operationsProgressTracker.AddPool(*operations_pool);
    
    const auto file_state = [self allocateFilePanelsWithFrame:frame
                                                    inContext:_context
                                                  withOpsPool:*operations_pool];
    file_state.closedPanelsHistory = self.closedPanelsHistory;
    file_state.favoriteLocationsStorage = self.favoriteLocationsStorage;
    
    window_controller.filePanelsState = file_state;
    
    [self addMainWindow:window_controller];
    return window_controller;
}

- (MainWindowController*)allocateDefaultMainWindow
{
    return [self allocateMainWindowInContext:CreationContext::Default];
}

- (MainWindowController*)allocateMainWindowRestoredManually
{
    return [self allocateMainWindowInContext:CreationContext::ManualRestoration];
}

- (MainWindowController*)allocateMainWindowRestoredBySystem
{
    return [self allocateMainWindowInContext:CreationContext::SystemRestoration];
}

@end

static bool RestoreFilePanelStateFromLastOpenedWindow(MainWindowFilePanelState *_state)
{
    const auto last = MainWindowController.lastFocused;
    if( !last )
        return  false;
    
    const auto source_state = last.filePanelsState;
    [_state.leftPanelController copyOptionsFromController:source_state.leftPanelController];
    [_state.rightPanelController copyOptionsFromController:source_state.rightPanelController];
    return true;
}
