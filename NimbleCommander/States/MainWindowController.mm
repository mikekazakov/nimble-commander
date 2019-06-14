// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "MainWindowController.h"
#include <Habanero/debug.h>
#include <Config/RapidJSON.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/writer.h>
#include <rapidjson/prettywriter.h>
#include <VFS/Native.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include "Terminal/ShellState.h"
#include "Terminal/ExternalEditorState.h"
#include "InternalViewer/MainWindowInternalViewerState.h"
#include "../GeneralUI/RegistrationInfoWindow.h"
#include <Utility/NativeFSManager.h>
#include "MainWindow.h"
#include "../Bootstrap/AppDelegate.h"
#include "../Bootstrap/AppDelegate+ViewerCreation.h"
#include "FilePanels/MainWindowFilePanelState.h"
#include "FilePanels/PanelController.h"
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <Habanero/SerialQueue.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <Utility/CocoaAppearanceManager.h>
#include <NimbleCommander/Core/UserNotificationsCenter.h>
#include <Operations/Pool.h>
#include <Utility/ObjCpp.h>
#include <Viewer/ViewerViewController.h>
#include <Viewer/InternalViewerWindowController.h>

using namespace nc;

static const auto g_ConfigShowToolbar = "general.showToolbar";
static const auto g_ConfigModalInternalViewer = "viewer.modalMode";

static auto g_CocoaRestorationFilePanelsStateKey = @"filePanelsState";
static const auto g_JSONRestorationFilePanelsStateKey = "filePanel.defaultState";
static __weak NCMainWindowController *g_LastFocusedNCMainWindowController = nil;

@interface NCMainWindowController()

@property (nonatomic, readonly) bool toolbarVisible;

@end

@implementation NCMainWindowController
{
    std::vector<NSObject<NCMainWindowState> *> m_WindowState; // .back is current state
    MainWindowFilePanelState    *m_PanelState;
    NCTermShellState     *m_Terminal;
    MainWindowInternalViewerState *m_Viewer;
    
    SerialQueue                  m_BigFileViewLoadingQ;
    bool                         m_ToolbarVisible;
    std::vector<config::Token>   m_ConfigTickets;
    
    std::shared_ptr<nc::ops::Pool> m_OperationsPool;
}

@synthesize terminalState = m_Terminal;
@synthesize toolbarVisible = m_ToolbarVisible;

+ (NCMainWindowController*)lastFocused
{
    return (NCMainWindowController*)g_LastFocusedNCMainWindowController;
}

- (instancetype) initWithWindow:(NCMainWindow*)window
{
    if( !window )
        return nil;
    
    self = [super initWithWindow:window];
    if( !self )
        return nil;

    window.delegate = self;
    
    
    m_ToolbarVisible = GlobalConfig().GetBool( g_ConfigShowToolbar );
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didBecomeKeyWindow)
                                               name:NSWindowDidBecomeKeyNotification
                                             object:self.window];
    
    auto callback = objc_callback(self, @selector(onConfigShowToolbarChanged));
    m_ConfigTickets.emplace_back(GlobalConfig().Observe(g_ConfigShowToolbar, move(callback)));
    
    [self invalidateRestorableState];
    
    return self;
}

-(void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
    assert( m_WindowState.empty() );
}

- (BOOL) isRestorable
{
    return true;
}

+ (void)restoreWindowWithIdentifier:(NSString *)[[maybe_unused]]_identifier
                              state:(NSCoder *)[[maybe_unused]]_state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    // this is a legacy stub. it needs to be here for some time.
    completionHandler(nil, nil);
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    if( auto panels_state = [m_PanelState encodeRestorableState];
        panels_state.GetType() != rapidjson::kNullType) {
        rapidjson::StringBuffer buffer;
        rapidjson::PrettyWriter<rapidjson::StringBuffer> writer(buffer);
        panels_state.Accept(writer);
        [coder encodeObject:[NSString stringWithUTF8String:buffer.GetString()]
                     forKey:g_CocoaRestorationFilePanelsStateKey];
    }
    
    [super encodeRestorableStateWithCoder:coder];
}

- (bool)restoreDefaultWindowStateFromConfig
{
    return [self.class restoreDefaultWindowStateFromConfig:m_PanelState];
}

+ (bool)restoreDefaultWindowStateFromConfig:(MainWindowFilePanelState*)_state
{
    // supposed to be called when windows are restored upon app start
    const auto panels_state = StateConfig().Get(g_JSONRestorationFilePanelsStateKey);
    if( panels_state.IsNull() )
        return false;
    
    return [_state decodeRestorableState:panels_state];
}

- (void)restoreDefaultWindowStateFromLastOpenedWindow
{
    // supposed to be called when new window is allocated
    NCMainWindowController *last = g_LastFocusedNCMainWindowController;
    if( !last )
        return;
    
    const auto file_state = last->m_PanelState;
    [m_PanelState.leftPanelController copyOptionsFromController:file_state.leftPanelController];
    [m_PanelState.rightPanelController copyOptionsFromController:file_state.rightPanelController];
}

+ (bool)canRestoreDefaultWindowStateFromLastOpenedWindow
{
    return g_LastFocusedNCMainWindowController != nil;
}

- (void)restoreStateWithCoder:(NSCoder *)coder
{
    const id encoded_state = [coder decodeObjectForKey:g_CocoaRestorationFilePanelsStateKey];
    if( auto json = objc_cast<NSString>(encoded_state) ) {
        nc::config::Document state;
        rapidjson::ParseResult ok = state.Parse<rapidjson::kParseCommentsFlag>( json.UTF8String );
        if( ok )
            [m_PanelState decodeRestorableState:state];
    }
    
    [super restoreStateWithCoder:coder];
}

- (bool)currentStateNeedWindowTitle
{
    const auto state = self.topmostState;
    if( !state )
        return false;
    if( [state respondsToSelector:@selector(windowStateNeedsTitle)] && state.windowStateNeedsTitle )
        return true;
    return false;
}

- (void) updateTitleAndToolbarVisibilityWith:(NSToolbar *)_toolbar
                              toolbarVisible:(bool)_toolbar_visible
                                  needsTitle:(bool)_needs_title
{
    self.window.toolbar = _toolbar;
    if( _toolbar )
        _toolbar.visible = _toolbar_visible;

    self.window.titleVisibility = _needs_title ?
        NSWindowTitleVisible :
        ( (_toolbar && _toolbar_visible) ?
            NSWindowTitleHidden :
            NSWindowTitleVisible );

    m_ToolbarVisible = _toolbar_visible;
}

static int CountMainWindows()
{
    int count = 0;
    for( NSWindow *wnd in NSApp.windows )
        if( [wnd isKindOfClass:NCMainWindow.class] )
             count++;
    return count;
}

- (void)windowWillClose:(NSNotification *)[[maybe_unused]]_notification
{
    // the are the last main window - need to save current state as "default" in state config
    if( CountMainWindows() == 1 ) {
        if( auto panels_state = [m_PanelState encodeRestorableState];
            panels_state.GetType() != rapidjson::kNullType )
            StateConfig().Set(g_JSONRestorationFilePanelsStateKey, panels_state);
        [m_PanelState saveDefaultInitialState];
    }
    
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(windowStateWillClose)])
            [i windowStateWillClose];

    self.window.contentView = nil;
    [self.window makeFirstResponder:nil];
    
    while(!m_WindowState.empty())
    {
        if([m_WindowState.back() respondsToSelector:@selector(windowStateDidResign)])
            [m_WindowState.back() windowStateDidResign];
        
        m_WindowState.pop_back();
    }
    m_PanelState = nil;
    m_Terminal = nil;
}

- (BOOL)windowShouldClose:(id)[[maybe_unused]]_sender
{
    for( auto i = m_WindowState.rbegin(), e = m_WindowState.rend(); i != e; ++i )
        if( [*i respondsToSelector:@selector(windowStateShouldClose:)] )
            if( ![*i windowStateShouldClose:self] )
                return false;
    
    if( m_Terminal != nil )
        if( ![m_Terminal windowStateShouldClose:self] )
            return false;
    
    return true;
}

- (void)didBecomeKeyWindow
{
    g_LastFocusedNCMainWindowController = self;
}

- (IBAction)OnShowToolbar:(id)[[maybe_unused]]_sender
{
    GlobalConfig().Set( g_ConfigShowToolbar, !GlobalConfig().GetBool(g_ConfigShowToolbar) );
}

- (void)onConfigShowToolbarChanged
{
    bool visible = GlobalConfig().GetBool( g_ConfigShowToolbar );
    [self updateTitleAndToolbarVisibilityWith:self.window.toolbar
                               toolbarVisible:visible
                                   needsTitle:self.currentStateNeedWindowTitle];
}

- (void) ResignAsWindowState:(id)_state
{
    dispatch_assert_main_queue();    
    assert(_state != m_PanelState);
    assert(m_WindowState.size() > 1);
    assert(self.topmostState == _state);

    bool is_terminal_resigning = self.topmostState == m_Terminal;
    
    if([self.topmostState respondsToSelector:@selector(windowStateDidResign)])
        [self.topmostState windowStateDidResign];
    m_WindowState.pop_back();
    
    self.window.contentView = self.topmostState.windowStateContentView;
    [self.window makeFirstResponder:self.window.contentView];
    
    if([self.topmostState respondsToSelector:@selector(windowStateDidBecomeAssigned)])
        [self.topmostState windowStateDidBecomeAssigned];
    
    // here we need to synchonize cwd in terminal and cwd in active file panel
    if(self.topmostState == m_PanelState && is_terminal_resigning && m_PanelState.isPanelActive) {
        if( auto pc = m_PanelState.activePanelController ){
            auto cwd = m_Terminal.cwd;
            if( pc.isUniform && (!pc.vfs->IsNativeFS() || pc.currentDirectoryPath != cwd) ) {
                auto cnt = std::make_shared<nc::panel::DirectoryChangeRequest>();
                cnt->VFS = VFSNativeHost::SharedHost();
                cnt->RequestedDirectory = cwd;
                [pc GoToDirWithContext:cnt];
            }
        }
    }

    [self updateTitleAndToolbarVisibilityWith:self.topmostState.windowStateToolbar
                               toolbarVisible:self.toolbarVisible
                                   needsTitle:self.currentStateNeedWindowTitle];
}

- (void) pushState:(NSObject<NCMainWindowState> *)_state
{
    dispatch_assert_main_queue();
    m_WindowState.push_back(_state);
    
    [self updateTitleAndToolbarVisibilityWith:self.topmostState.windowStateToolbar
                               toolbarVisible:self.toolbarVisible
                                   needsTitle:self.currentStateNeedWindowTitle];
    
    self.window.contentView = self.topmostState.windowStateContentView;
    [self.window makeFirstResponder:self.window.contentView];
    
    if([self.topmostState respondsToSelector:@selector(windowStateDidBecomeAssigned)])
        [self.topmostState windowStateDidBecomeAssigned];
}

- (void)requestViewerFor:(std::string)_filepath at:(std::shared_ptr<VFSHost>) _host
{
    dispatch_assert_main_queue();
    
    if( !m_BigFileViewLoadingQ.Empty() )
        return;
    
    m_BigFileViewLoadingQ.Run([=]{
        
        if( GlobalConfig().GetBool(g_ConfigModalInternalViewer) ) { // as a state
            if( !m_Viewer )
            dispatch_sync(dispatch_get_main_queue(),[&]{
                auto rc = NSMakeRect(0, 0, 100, 100);
                auto viewer_factory = [](NSRect rc){
                    return [NCAppDelegate.me makeViewerWithFrame:rc];
                };
                auto ctrl = [NCAppDelegate.me makeViewerController];
                m_Viewer = [[MainWindowInternalViewerState alloc] initWithFrame:rc
                                                                  viewerFactory:viewer_factory
                                                                     controller:ctrl];
            });
            if( [m_Viewer openFile:_filepath atVFS:_host] ) {
                dispatch_to_main_queue([=]{
                    [self pushState:m_Viewer];
                });
            }
        }
        else { // as a window
            if( auto *ex_window = [NCAppDelegate.me findInternalViewerWindowForPath:_filepath
                                                                              onVFS:_host] ) {
                // already has this one
                dispatch_to_main_queue([=]{
                    [ex_window showWindow:self];
                });
            }
            else {
                InternalViewerWindowController *window = nil;
                dispatch_sync(dispatch_get_main_queue(),[&]{
                    window = [NCAppDelegate.me retrieveInternalViewerWindowForPath:_filepath
                                                                             onVFS:_host];
                });
                const auto opening_result = [window performBackgrounOpening];
                dispatch_to_main_queue([=]{
                    if( opening_result ) {
                        [window showAsFloatingWindow];
                    }
                });
            }
        }
    });
}

- (void)requestTerminal:(const std::string&)_cwd
{
    if( m_Terminal == nil ) {
        const auto state = [[NCTermShellState alloc] initWithFrame:self.window.contentView.frame];
        state.initialWD = _cwd;
        [self pushState:state];
        m_Terminal = state;
    }
    else {
        [self pushState:m_Terminal];
        [m_Terminal chDir:_cwd];
    }
}

- (void)requestTerminalExecution:(const char*)_filename at:(const char*)_cwd
{
    [self requestTerminalExecution:_filename at:_cwd withParameters:nullptr];
}

- (void)requestTerminalExecution:(const char*)_filename
                              at:(const char*)_cwd
                  withParameters:(const char*)_params
{
    if( m_Terminal == nil ) {
        const auto state = [[NCTermShellState alloc] initWithFrame:self.window.contentView.frame];
        state.initialWD = std::string(_cwd);
        [self pushState:state];
        m_Terminal = state;
    }
    else {
        [self pushState:m_Terminal];
    }
    [m_Terminal execute:_filename at:_cwd parameters:_params];
}

- (void)requestTerminalExecutionWithFullPath:(const char*)_binary_path
                              withParameters:(const char*)_params
{
    dispatch_assert_main_queue();
    
    if( m_Terminal == nil ) {
        const auto state = [[NCTermShellState alloc] initWithFrame:self.window.contentView.frame];
        if( PanelController *pc = m_PanelState.activePanelController )
            if( pc.isUniform && pc.vfs->IsNativeFS() )
                state.initialWD = pc.currentDirectoryPath;
        [self pushState:state];
        m_Terminal = state;
    }
    else {
        [self pushState:m_Terminal];
    }
    [m_Terminal executeWithFullPath:_binary_path parameters:_params];
}

- (void)RequestExternalEditorTerminalExecution:(const std::string&)_full_app_path
                                        params:(const std::string&)_params
                                     fileTitle:(const std::string&)_file_title
{
    const auto frame = self.window.contentView.frame;
    const auto state = [[NCTermExternalEditorState alloc] initWithFrameAndParams:frame
                                                                          binary:_full_app_path
                                                                          params:_params
                                                                       fileTitle:_file_title];
    [self pushState:state];
}

- (id<NCMainWindowState>) topmostState
{
    return m_WindowState.empty() ? nil : m_WindowState.back();
}

static const auto g_HideToolbarTitle = NSLocalizedString(@"Hide Toolbar", "Menu item title");
static const auto g_ShowToolbarTitle = NSLocalizedString(@"Show Toolbar", "Menu item title");
- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    IF_MENU_TAG("menu.view.show_toolbar") {
        item.title = self.toolbarVisible ? g_HideToolbarTitle : g_ShowToolbarTitle;
        return self.window.toolbar != nil;
    }
    return true;
}

- (IBAction)onMainMenuPerformShowRegistrationInfo:(id)[[maybe_unused]]sender
{
    RegistrationInfoWindow *w = [[RegistrationInfoWindow alloc] init];
    [self.window beginSheet:w.window completionHandler:^(NSModalResponse){}];    
}

- (void)enqueueOperation:(const std::shared_ptr<nc::ops::Operation> &)_operation
{
    m_OperationsPool->Enqueue(_operation);
}

- (nc::ops::Pool&)operationsPool
{
    return *m_OperationsPool;
}

- (void)beginSheet:(NSWindow *)sheetWindow completionHandler:(void (^)(NSModalResponse rc))handler
{
    nc::utility::CocoaAppearanceManager::Instance().ManageWindowApperance(sheetWindow);
    __block NSWindow *wnd = sheetWindow;
    __block NSWindowController *ctrl = wnd.windowController;
    if( auto name = ctrl.className.UTF8String)
        GA().PostScreenView(name);
    [self.window beginSheet:sheetWindow completionHandler:^(NSModalResponse _r){
        if( handler )
            handler(_r);
        wnd = nil;
        ctrl = nil;
    }];
}

- (MainWindowFilePanelState*)filePanelsState
{
    return m_PanelState;
}

- (void)setFilePanelsState:(MainWindowFilePanelState *)filePanelsState
{
    assert( m_PanelState == nil ); // at this moment we don't support overrring of existing panel.
    assert( m_WindowState.empty() );
    assert( filePanelsState != nil );
    
    m_PanelState = filePanelsState;
    [self pushState:m_PanelState];
}

- (void)setOperationsPool:(nc::ops::Pool&)_pool
{
    assert( m_OperationsPool == nullptr ); // at this moment we don't support overriding of a pool.
    m_OperationsPool = _pool.shared_from_this();
    
    __weak NCMainWindowController *weak_self = self;
    auto dialog_callback = [weak_self](NSWindow *_dlg, std::function<void (NSModalResponse)> _cb) {
        NSBeep();
        if( NCMainWindowController *wnd = weak_self)
            [wnd beginSheet:_dlg completionHandler:^(NSModalResponse rc) { _cb(rc); }];
    };
    m_OperationsPool->SetDialogCallback( std::move(dialog_callback) );
    
    auto completion_callback = [weak_self] (const std::shared_ptr<nc::ops::Operation>& _op) {
        if( NCMainWindowController *wnd = weak_self)
            dispatch_to_main_queue([=]{
                auto &center = core::UserNotificationsCenter::Instance();
                center.ReportCompletedOperation(*_op, wnd.window);
            });
    };
    m_OperationsPool->SetOperationCompletionCallback( std::move(completion_callback) );
}

- (NSRect)window:(NSWindow*)[[maybe_unused]]_window
    willPositionSheet:(NSWindow*)[[maybe_unused]] sheet
            usingRect:(NSRect)rect
{
    /**
     * At this moment the file panels state uses a horizontal separator line to place its content.
     * As a consequence, its toolbar doesn't have a bottom separator.
     * This leads to situation when dialogs look weird - like thay are placed wrongly.
     * To fix it - just offset the opening dialog window by 1px down.
     */
    if( self.window.toolbar != nil && self.window.toolbar.visible == true ) {
        rect.origin.y -= 1.;
    }
    return rect;
}

@end
