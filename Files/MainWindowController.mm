
//
//  MainWindowController.m
//  Directories
//
//  Created by Michael G. Kazakov on 09.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/debug.h>
#include "3rd_party/rapidjson/include/rapidjson/stringbuffer.h"
#include "3rd_party/rapidjson/include/rapidjson/writer.h"
#include "3rd_party/rapidjson/include/rapidjson/prettywriter.h"
#include "vfs/vfs_native.h"
#include "States/Terminal/MainWindowTerminalState.h"
#include "States/Terminal/MainWindowExternalTerminalEditorState.h"
#include "States/Viewer/MainWindowBigFileViewState.h"
#include "Utility/SystemInformation.h"
#include "MainWindowController.h"
#include "MainWindow.h"
#include "AppDelegate.h"
#include "QuickPreview.h"
#include "MainWindowFilePanelState.h"
#include "PanelController.h"
#include "ActionsShortcutsManager.h"
#include "ActivationManager.h"

static const auto g_ConfigShowToolbar = "general.showToolbar";
static auto g_CocoaRestorationFilePanelsStateKey = @"filePanelsState";
static const auto g_JSONRestorationFilePanelsStateKey = "filePanel.defaultState";
static __weak MainWindowController *g_LastFocusedMainWindowController = nil;

@implementation MainWindowController
{
    vector<NSObject<MainWindowStateProtocol> *> m_WindowState; // .back is current state
    MainWindowFilePanelState    *m_PanelState;
    MainWindowTerminalState     *m_Terminal;
    SerialQueue                  m_BigFileViewLoadingQ;
    bool                         m_ToolbarVisible;
    vector<GenericConfig::ObservationTicket> m_ConfigObservationTicktets;
}

@synthesize filePanelsState = m_PanelState;
@synthesize terminalState = m_Terminal;
@synthesize toolbarVisible = m_ToolbarVisible;

- (id)init {
    MainWindow* window = [[MainWindow alloc] initWithContentRect:NSMakeRect(100, 100, 1000, 600)
                                                       styleMask:NSResizableWindowMask|NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSTexturedBackgroundWindowMask
                                                         backing:NSBackingStoreBuffered
                                                           defer:false];
    window.minSize = NSMakeSize(640, 480);
    window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    window.restorable = YES;
    window.restorationClass = self.class;
    window.identifier = NSStringFromClass(self.class);
    window.title = @"";
    if(![window setFrameUsingName:NSStringFromClass(self.class)])
        [window center];

    [window setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
    [window setContentBorderThickness:40 forEdge:NSMinYEdge];
    
    if(self = [super initWithWindow:window]) {
        m_BigFileViewLoadingQ = SerialQueueT::Make(ActivationManager::Instance().BundleID() + ".bigfileviewloading");
        self.shouldCascadeWindows = NO;
        window.delegate = self;
        
        m_ToolbarVisible = GlobalConfig().GetBool( g_ConfigShowToolbar );
        
        m_PanelState = [[MainWindowFilePanelState alloc] initWithFrame:[self.window.contentView frame]
                                                                Window:self.window];
        
        if( m_PanelState.toolbar && m_ToolbarVisible ) { // ugly hack with hard-coded toolbar height to fix-up invalid window size after restoring
            NSRect rc = self.window.frame;
            auto toolbar_height = 38;
            rc.origin.y -= toolbar_height;
            rc.size.height += toolbar_height;
            [self.window setFrame:rc display:false];
        }
        
        [self PushNewWindowState:m_PanelState];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(didBecomeKeyWindow)
                                                   name:NSWindowDidBecomeKeyNotification
                                                 object:self.window];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(applicationWillTerminate)
                                                   name:NSApplicationWillTerminateNotification
                                                 object:NSApplication.sharedApplication];
        __weak MainWindowController* weak_self = self;
        m_ConfigObservationTicktets.emplace_back( GlobalConfig().Observe(g_ConfigShowToolbar, [=]{ [(MainWindowController*)weak_self onConfigShowToolbarChanged]; }) );
    }
    
    return self;
}

-(void) dealloc
{
    [self.window saveFrameUsingName:NSStringFromClass(self.class)];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    assert(m_WindowState.empty());
}

- (BOOL) isRestorable
{
    return true;
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    AppDelegate *delegate = (AppDelegate*)NSApplication.sharedApplication.delegate;
    if(delegate.isRunningTests) {
        completionHandler(nil, nil);
        return;
    }
//  looks like current bugs in OSX10.10. uncomment this later:
//    if(configuration::is_sandboxed && [NSApp modalWindow] != nil)
//        return;
    
    NSWindow *window = nil;
    if ([identifier isEqualToString:NSStringFromClass(self.class)])
    {

        window = [delegate AllocateNewMainWindow].window;
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
    auto panels_state = StateConfig().Get(g_JSONRestorationFilePanelsStateKey);
    if( !panels_state.IsNull() )
        [m_PanelState decodeRestorableState:panels_state];
}

- (void)restoreDefaultWindowStateFromLastOpenedWindow
{
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

- (void) updateTitleAndToolbarVisibilityWith:(NSToolbar *)_toolbar toolbarVisible:(bool)_toolbar_visible needsTitle:(bool)_needs_title
{
    auto frame = self.window.frame;
    [NSAnimationContext beginGrouping];
    
    self.window.toolbar = _toolbar;
    if(self.window.toolbar)
        self.window.toolbar.visible = _toolbar_visible;

    self.window.titleVisibility = _needs_title ? NSWindowTitleVisible : ( (_toolbar && _toolbar_visible) ? NSWindowTitleHidden : NSWindowTitleVisible );

    // for non-fullscreen windows we fix up window size after showing/hiding toolbar so it looks more solid
    if( (self.window.styleMask & NSFullScreenWindowMask) == 0)
        [self.window setFrame:frame display:true animate:false];
    
    [NSAnimationContext endGrouping];
    m_ToolbarVisible = _toolbar_visible;
}

- (void)applicationWillTerminate
{
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(OnApplicationWillTerminate)])
            [i OnApplicationWillTerminate];
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
    
    [AppDelegate.me RemoveMainWindow:self];
}

- (BOOL)windowShouldClose:(id)sender {
    for(auto i = m_WindowState.rbegin(), e = m_WindowState.rend(); i != e; ++i)
        if([*i respondsToSelector:@selector(WindowShouldClose:)])
            if(![*i WindowShouldClose:self])
                return false;
    
    if(m_Terminal != nil)
        if(![m_Terminal WindowShouldClose:self])
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

- (void)windowWillBeginSheet:(NSNotification *)notification
{
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(WindowWillBeginSheet)])
            [i WindowWillBeginSheet];
}

- (void)windowDidEndSheet:(NSNotification *)notification
{
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(WindowDidEndSheet)])
            [i WindowDidEndSheet];
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

- (void) PushNewWindowState:(NSObject<MainWindowStateProtocol> *)_state
{
    m_WindowState.push_back(_state);
    
    [self updateTitleAndToolbarVisibilityWith:self.topmostState.toolbar
                               toolbarVisible:self.toolbarVisible
                                   needsTitle:self.currentStateNeedWindowTitle];
    
    self.window.contentView = self.topmostState.windowContentView;
    [self.window makeFirstResponder:self.window.contentView];
    
    if([self.topmostState respondsToSelector:@selector(Assigned)])
        [self.topmostState Assigned];
}

- (OperationsController*) OperationsController
{
    return m_PanelState.OperationsController;
}

- (void) RequestBigFileView:(string)_filepath with_fs:(shared_ptr<VFSHost>) _host
{
    if(!m_BigFileViewLoadingQ->Empty())
        return;
    
    m_BigFileViewLoadingQ->Run([=]{
        auto frame = [self.window.contentView frame];
        MainWindowBigFileViewState *state = [[MainWindowBigFileViewState alloc] initWithFrame:frame];
        
        if([state OpenFile:_filepath.c_str() with_fs:_host])
            dispatch_to_main_queue([=]{
                [self PushNewWindowState:state];
            });
    });
}

- (void)RequestTerminal:(const string&)_cwd;
{
    if(m_Terminal == nil)
    {
        MainWindowTerminalState *state = [[MainWindowTerminalState alloc] initWithFrame:[self.window.contentView frame]];
        [state SetInitialWD:_cwd];
        [self PushNewWindowState:state];
        m_Terminal = state;
    }
    else
    {
        [self PushNewWindowState:m_Terminal];
        [m_Terminal ChDir:_cwd.c_str()];
    }
}

- (void)RequestTerminalExecution:(const char*)_filename at:(const char*)_cwd
{
    [self requestTerminalExecution:_filename at:_cwd withParameters:nullptr];
}

- (void)requestTerminalExecution:(const char*)_filename at:(const char*)_cwd withParameters:(const char*)_params
{
    if(m_Terminal == nil) {
        MainWindowTerminalState *state = [[MainWindowTerminalState alloc] initWithFrame:self.window.contentView.frame];
        [state SetInitialWD:_cwd];
        [self PushNewWindowState:state];
        m_Terminal = state;
    }
    else {
        [self PushNewWindowState:m_Terminal];
    }
    [m_Terminal Execute:_filename at:_cwd with_parameters:_params];
}

- (void)requestTerminalExecutionWithFullPath:(const char*)_binary_path withParameters:(const char*)_params
{
    if(m_Terminal == nil) {
        MainWindowTerminalState *state = [[MainWindowTerminalState alloc] initWithFrame:self.window.contentView.frame];
        [self PushNewWindowState:state];
        m_Terminal = state;
    }
    else {
        [self PushNewWindowState:m_Terminal];
    }
    [m_Terminal Execute:_binary_path with_parameters:_params];
}

- (void)RequestExternalEditorTerminalExecution:(const string&)_full_app_path
                                        params:(const string&)_params
                                          file:(const string&)_file_path
{
    auto frame = [self.window.contentView frame];
    MainWindowExternalTerminalEditorState *state = [MainWindowExternalTerminalEditorState alloc];
    state = [state initWithFrameAndParams:frame
                                   binary:_full_app_path
                                   params:_params
                                     file:_file_path
             ];
    [self PushNewWindowState:state];
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

@end
