
//
//  MainWindowController.m
//  Directories
//
//  Created by Michael G. Kazakov on 09.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/debug.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/writer.h>
#include <rapidjson/prettywriter.h>
#include <VFS/Native.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include "Terminal/MainWindowTerminalState.h"
#include "Terminal/TermShellTask.h"
#include "Terminal/MainWindowExternalTerminalEditorState.h"
#include "InternalViewer/MainWindowInternalViewerState.h"
#include "../Viewer/InternalViewerWindowController.h"
#include "../GeneralUI/RegistrationInfoWindow.h"
#include <Utility/NativeFSManager.h>
#include "MainWindowController.h"
#include "MainWindow.h"
#include "../Bootstrap/AppDelegate.h"
#include "FilePanels/MainWindowFilePanelState.h"
#include "FilePanels/PanelController.h"
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>

static const auto g_ConfigShowToolbar = "general.showToolbar";
static const auto g_ConfigModalInternalViewer = "viewer.modalMode";

static auto g_CocoaRestorationFilePanelsStateKey = @"filePanelsState";
static const auto g_JSONRestorationFilePanelsStateKey = "filePanel.defaultState";
static __weak MainWindowController *g_LastFocusedMainWindowController = nil;

@interface MainWindowController()

@property (nonatomic, readonly) bool toolbarVisible;

@end

@implementation MainWindowController
{
    vector<NSObject<MainWindowStateProtocol> *> m_WindowState; // .back is current state
    MainWindowFilePanelState    *m_PanelState;
    MainWindowTerminalState     *m_Terminal;
    MainWindowInternalViewerState *m_Viewer;
    
    SerialQueue                  m_BigFileViewLoadingQ;
    bool                         m_ToolbarVisible;
    vector<GenericConfig::ObservationTicket> m_ConfigTickets;
}

@synthesize filePanelsState = m_PanelState;
@synthesize terminalState = m_Terminal;
@synthesize toolbarVisible = m_ToolbarVisible;

- (instancetype)initBase
{
    auto window = [[MainWindow alloc] init];
    if( !window )
        return nil;
      
    if( self = [super initWithWindow:window] ) {
        self.shouldCascadeWindows = NO;
        window.delegate = self;
        window.restorationClass = self.class;

        m_ToolbarVisible = GlobalConfig().GetBool( g_ConfigShowToolbar );

        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(didBecomeKeyWindow)
                                                   name:NSWindowDidBecomeKeyNotification
                                                 object:self.window];
        
        m_ConfigTickets.emplace_back( GlobalConfig().Observe(g_ConfigShowToolbar,
            objc_callback(self, @selector(onConfigShowToolbarChanged))) );
        
        [AppDelegate.me addMainWindow:self];
        
        [self invalidateRestorableState];
    }
    return self;
}

- (instancetype) initDefaultWindow
{
    if( self = [self initBase] ) {
       
        m_PanelState = [[MainWindowFilePanelState alloc] initWithFrame:
            self.window.contentView.frame];
        
        [self pushState:m_PanelState];
    }
    
    return self;
}

- (instancetype) initWithLastOpenedWindowOptions
{
    if( self = [self initBase] ) {
        
        // almost "free" state initially
        m_PanelState = [[MainWindowFilePanelState alloc] initEmptyFileStateWithFrame:
            self.window.contentView.frame];

        // copy options from previous window, if there's any
        [self restoreDefaultWindowStateFromLastOpenedWindow];

        // load initial contents
        [m_PanelState loadDefaultPanelContent];
        
        // run the state
        [self pushState:m_PanelState];
    }
    return self;
}

- (instancetype) initRestoringLastWindowFromConfig
{
    if( self = [self initBase] ) {
        
        // almost "free" state initially
        m_PanelState = [[MainWindowFilePanelState alloc] initEmptyFileStateWithFrame:
            self.window.contentView.frame];
        
        [self restoreDefaultWindowStateFromConfig];
        
        // run the state
        [self pushState:m_PanelState];
    }
    return self;
}

- (instancetype) initForSystemRestoration
{
   if( self = [self initBase] ) {
        
        // almost "free" state initially
        m_PanelState = [[MainWindowFilePanelState alloc] initEmptyFileStateWithFrame:
            self.window.contentView.frame];
       
        // run the state
        [self pushState:m_PanelState];
    }
    return self;
}

- (instancetype) init
{
    return [self initDefaultWindow];
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

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    if( AppDelegate.me.isRunningTests ) {
        completionHandler(nil, nil);
        return;
    }
//  looks like current bugs in OSX10.10. uncomment this later:
//    if(configuration::is_sandboxed && [NSApp modalWindow] != nil)
//        return;
    
    NSWindow *window = nil;
    if( [identifier isEqualToString:MainWindow.defaultIdentifier] ) {
        auto ctrl = [[MainWindowController alloc] initForSystemRestoration];
        window = ctrl.window;
    }
    completionHandler(window, nil);
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    if( auto panels_state = [m_PanelState encodeRestorableState] ) {
        rapidjson::StringBuffer buffer;
//        rapidjson::Writer<rapidjson::StringBuffer> writer(buffer);
        rapidjson::PrettyWriter<rapidjson::StringBuffer> writer(buffer);
        panels_state->Accept(writer);
//        if(AmIBeingDebugged())
//            cout << buffer.GetString() << endl;
        [coder encodeObject:[NSString stringWithUTF8String:buffer.GetString()] forKey:g_CocoaRestorationFilePanelsStateKey];
    }
    
    [super encodeRestorableStateWithCoder:coder];
}

- (void)restoreDefaultWindowStateFromConfig
{
    // supposed to be called when windows are restored upon app start
    auto panels_state = StateConfig().Get(g_JSONRestorationFilePanelsStateKey);
    if( !panels_state.IsNull() )
        [m_PanelState decodeRestorableState:panels_state];
}

- (void)restoreDefaultWindowStateFromLastOpenedWindow
{
    // supposed to be called when new window is allocated
    if( MainWindowController *last = g_LastFocusedMainWindowController ) {
        [m_PanelState.leftPanelController copyOptionsFromController:last->m_PanelState.leftPanelController];
        [m_PanelState.rightPanelController copyOptionsFromController:last->m_PanelState.rightPanelController];
    }
}

- (void)restoreStateWithCoder:(NSCoder *)coder
{
    if( auto json = objc_cast<NSString>([coder decodeObjectForKey:g_CocoaRestorationFilePanelsStateKey]) ) {
//        if(AmIBeingDebugged())
//            NSLog(@"%@", json);
        rapidjson::StandaloneDocument state;
        rapidjson::ParseResult ok = state.Parse<rapidjson::kParseCommentsFlag>( json.UTF8String );
        if( ok )
            [m_PanelState decodeRestorableState:state];
    }
    
    [super restoreStateWithCoder:coder];
}

- (bool)currentStateNeedWindowTitle
{
    auto state = self.topmostState;
    if(state && [state respondsToSelector:@selector(needsWindowTitle)] && [state needsWindowTitle])
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

- (void)windowDidResize:(NSNotification *)notification
{
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(WindowDidResize)])
            [i WindowDidResize];
}

- (void)windowWillClose:(NSNotification *)notification
{
    // the are the last main window - need to save current state as "default" in state config
    if( AppDelegate.me.mainWindowControllers.size() == 1 )
        if( auto panels_state = [m_PanelState encodeRestorableState] )
            StateConfig().Set(g_JSONRestorationFilePanelsStateKey, *panels_state);
    
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(WindowWillClose)])
            [i WindowWillClose];

    self.window.contentView = nil;
    [self.window makeFirstResponder:nil];
    
    while(!m_WindowState.empty())
    {
        if([m_WindowState.back() respondsToSelector:@selector(Resigned)])
            [m_WindowState.back() Resigned];
        
        m_WindowState.pop_back();
    }
    m_PanelState = nil;
    m_Terminal = nil;
    
    [AppDelegate.me removeMainWindow:self];
}

- (BOOL)windowShouldClose:(id)sender
{
    for( auto i = m_WindowState.rbegin(), e = m_WindowState.rend(); i != e; ++i )
        if( [*i respondsToSelector:@selector(WindowShouldClose:)] )
            if( ![*i WindowShouldClose:self] )
                return false;
    
    if( m_Terminal != nil )
        if( ![m_Terminal WindowShouldClose:self] )
            return false;
    
    return true;
}

- (void)didBecomeKeyWindow
{
    g_LastFocusedMainWindowController = self;
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(didBecomeKeyWindow)])
            [i didBecomeKeyWindow];
}

- (IBAction)OnShowToolbar:(id)sender
{
    GlobalConfig().Set( g_ConfigShowToolbar, !GlobalConfig().GetBool(g_ConfigShowToolbar) );
}

- (void)onConfigShowToolbarChanged
{
    bool visible = GlobalConfig().GetBool( g_ConfigShowToolbar );
    [self updateTitleAndToolbarVisibilityWith:self.window.toolbar toolbarVisible:visible needsTitle:self.currentStateNeedWindowTitle];
}

- (void) ResignAsWindowState:(id)_state
{
    dispatch_assert_main_queue();    
    assert(_state != m_PanelState);
    assert(m_WindowState.size() > 1);
    assert(self.topmostState == _state);

    bool is_terminal_resigning = self.topmostState == m_Terminal;
    
    if([self.topmostState respondsToSelector:@selector(Resigned)])
        [self.topmostState Resigned];
    m_WindowState.pop_back();
    
    self.window.contentView = self.topmostState.windowContentView;
    [self.window makeFirstResponder:self.window.contentView];
    
    if([self.topmostState respondsToSelector:@selector(Assigned)])
        [self.topmostState Assigned];
    
    // here we need to synchonize cwd in terminal and cwd in active file panel
    if(self.topmostState == m_PanelState && is_terminal_resigning && m_PanelState.isPanelActive) {
        if( auto pc = m_PanelState.activePanelController ){
            auto cwd = m_Terminal.CWD;
            if( pc.isUniform && (!pc.vfs->IsNativeFS() || pc.currentDirectoryPath != cwd) ) {
                auto cnt = make_shared<PanelControllerGoToDirContext>();
                cnt->VFS = VFSNativeHost::SharedHost();
                cnt->RequestedDirectory = cwd;
                [pc GoToDirWithContext:cnt];
            }
        }
    }

    [self updateTitleAndToolbarVisibilityWith:self.topmostState.toolbar
                               toolbarVisible:self.toolbarVisible
                                   needsTitle:self.currentStateNeedWindowTitle];
}

- (void) pushState:(NSObject<MainWindowStateProtocol> *)_state
{
    dispatch_assert_main_queue();
    m_WindowState.push_back(_state);
    
//    MachTimeBenchmark mtb;
    
    [self updateTitleAndToolbarVisibilityWith:self.topmostState.toolbar
                               toolbarVisible:self.toolbarVisible
                                   needsTitle:self.currentStateNeedWindowTitle];
//    mtb.ResetMicro("  [self updateTitleAndToolbarVisibilityWith ");
    
    
    self.window.contentView = self.topmostState.windowContentView;
//    mtb.ResetMicro("  self.window.contentView = ");
    
    [self.window makeFirstResponder:self.window.contentView];
//    mtb.ResetMicro("  [self.window makeFirstResponder ");
    
    if([self.topmostState respondsToSelector:@selector(Assigned)])
        [self.topmostState Assigned];
    
//    mtb.ResetMicro("  [self.topmostState Assigned] ");
}

- (OperationsController*) OperationsController
{
    return m_PanelState.OperationsController;
}

- (void) RequestBigFileView:(string)_filepath with_fs:(shared_ptr<VFSHost>) _host
{
    dispatch_assert_main_queue();
    
    if( !m_BigFileViewLoadingQ.Empty() )
        return;
    
    m_BigFileViewLoadingQ.Run([=]{
        
        if( GlobalConfig().GetBool(g_ConfigModalInternalViewer) ) { // as a state
            if( !m_Viewer )
            dispatch_sync(dispatch_get_main_queue(),[&]{
                m_Viewer = [[MainWindowInternalViewerState alloc] init];
            });
            if( [m_Viewer openFile:_filepath atVFS:_host] ) {
                dispatch_to_main_queue([=]{
                    [self pushState:m_Viewer];
                });
            }
        }
        else { // as a window
            if( InternalViewerWindowController *window = [AppDelegate.me findInternalViewerWindowForPath:_filepath onVFS:_host] ) {
                // already has this one
                dispatch_to_main_queue([=]{
                    [window showWindow:self];
                });
            }
            else {
                // need to create a new one
                dispatch_sync(dispatch_get_main_queue(),[&]{
                    window = [[InternalViewerWindowController alloc] initWithFilepath:_filepath at:_host];
                });
                if( [window performBackgrounOpening] ) {
                    dispatch_to_main_queue([=]{
                        [window showAsFloatingWindow];
                    });
                }
                else
                    dispatch_to_main_queue([=] () mutable {
                        window = nil; // release this object in main thread
                    });
            }
        }
    });
}

- (void)requestTerminal:(const string&)_cwd;
{
    if(m_Terminal == nil) {
        MainWindowTerminalState *state = [[MainWindowTerminalState alloc] initWithFrame:[self.window.contentView frame]];
        [state SetInitialWD:_cwd];
        [self pushState:state];
        m_Terminal = state;
    }
    else {
        [self pushState:m_Terminal];
        [m_Terminal ChDir:_cwd.c_str()];
    }
}

- (void)requestTerminalExecution:(const char*)_filename at:(const char*)_cwd
{
    [self requestTerminalExecution:_filename at:_cwd withParameters:nullptr];
}

- (void)requestTerminalExecution:(const char*)_filename at:(const char*)_cwd withParameters:(const char*)_params
{
    if(m_Terminal == nil) {
        MainWindowTerminalState *state = [[MainWindowTerminalState alloc] initWithFrame:self.window.contentView.frame];
        [state SetInitialWD:_cwd];
        [self pushState:state];
        m_Terminal = state;
    }
    else {
        [self pushState:m_Terminal];
    }
    [m_Terminal Execute:_filename at:_cwd with_parameters:_params];
}

- (void)requestTerminalExecutionWithFullPath:(const char*)_binary_path withParameters:(const char*)_params
{
    dispatch_assert_main_queue();
    
    if(m_Terminal == nil) {
        MainWindowTerminalState *state = [[MainWindowTerminalState alloc] initWithFrame:self.window.contentView.frame];
        if( PanelController *pc = m_PanelState.activePanelController )
            if( pc.isUniform && pc.vfs->IsNativeFS() )
                [state SetInitialWD:pc.currentDirectoryPath];
        [self pushState:state];
        m_Terminal = state;
    }
    else {
        [self pushState:m_Terminal];
    }
    [m_Terminal Execute:_binary_path with_parameters:_params];
}

- (void)RequestExternalEditorTerminalExecution:(const string&)_full_app_path
                                        params:(const string&)_params
                                     fileTitle:(const string&)_file_title
{
    auto frame = [self.window.contentView frame];
    MainWindowExternalTerminalEditorState *state = [MainWindowExternalTerminalEditorState alloc];
    state = [state initWithFrameAndParams:frame
                                   binary:_full_app_path
                                   params:_params
                                fileTitle:_file_title
             ];
    [self pushState:state];
}

- (id<MainWindowStateProtocol>) topmostState
{
    return m_WindowState.empty() ? nil : m_WindowState.back();
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    IF_MENU_TAG("menu.view.show_toolbar") {
        item.title = self.toolbarVisible ?
            NSLocalizedString(@"Hide Toolbar", "Menu item title"):
            NSLocalizedString(@"Show Toolbar", "Menu item title");
        return self.window.toolbar != nil;
    }
    return true;
}

- (IBAction)onMainMenuPerformShowRegistrationInfo:(id)sender
{
    RegistrationInfoWindow *w = [[RegistrationInfoWindow alloc] init];
    [self.window beginSheet:w.window completionHandler:^(NSModalResponse){}];    
}

@end
