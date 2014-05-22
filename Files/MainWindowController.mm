
//
//  MainWindowController.m
//  Directories
//
//  Created by Michael G. Kazakov on 09.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowController.h"
#import "AppDelegate.h"
#import "QuickPreview.h"
#import "BigFileView.h"
#import "MainWindowBigFileViewState.h"
#import "MainWindowFilePanelState.h"
#import "MainWindowTerminalState.h"
#import "MainWindowExternalTerminalEditorState.h"
#import "PanelController.h"
#import "MyToolbar.h"
#import "Common.h"

static double TitleBarHeight()
{
    static double h = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSRect frame = NSMakeRect (0, 0, 100, 100);
        NSRect contentRect;
        contentRect = [NSWindow contentRectForFrameRect:frame
                                              styleMask:NSTitledWindowMask];
        
        h = (frame.size.height - contentRect.size.height);
    });
    return h;
}

@implementation MainWindowController
{
    vector<NSObject<MainWindowStateProtocol> *> m_WindowState; // .back is current state
    MainWindowFilePanelState    *m_PanelState;
    MainWindowTerminalState     *m_Terminal;
    SerialQueue                  m_BigFileViewLoadingQ;
}

@synthesize FilePanelState = m_PanelState;
@synthesize TerminalState = m_Terminal;

- (id)init {
    NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 100, 1000, 600)
                                                   styleMask:NSResizableWindowMask|NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSTexturedBackgroundWindowMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:false];
    window.minSize = NSMakeSize(660, 480);
    window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    window.restorable = YES;
    window.restorationClass = self.class;
    window.identifier = NSStringFromClass(self.class);
    window.title = @"Files αλφα ver.";
    if(![window setFrameUsingName:NSStringFromClass(self.class)])
        [window center];
    
    [window setAutorecalculatesContentBorderThickness:NO forEdge:NSMaxYEdge];
    [window setContentBorderThickness:36 forEdge:NSMaxYEdge];
    [window setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
    [window setContentBorderThickness:0 forEdge:NSMinYEdge];

    
    if(self = [super initWithWindow:window]) {
        m_BigFileViewLoadingQ = SerialQueueT::Make("info.filesmanager.bigfileviewloading");
        self.ShouldCascadeWindows = NO;
        window.Delegate = self;
        
        m_PanelState = [[MainWindowFilePanelState alloc] initWithFrame:[self.window.contentView frame]
                                                                Window:self.window];
        [self PushNewWindowState:m_PanelState];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(DidBecomeKeyWindow)
                                                   name:NSWindowDidBecomeKeyNotification
                                                 object:self.window];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(applicationWillTerminate)
                                                   name:NSApplicationWillTerminateNotification
                                                 object:NSApplication.sharedApplication];
    }
    
    return self;
}

-(void) dealloc
{
    [self.window saveFrameUsingName:NSStringFromClass(self.class)];
    
    [NSNotificationCenter.defaultCenter removeObserver:self];
    assert(m_WindowState.empty());
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    AppDelegate *delegate = (AppDelegate*)NSApplication.sharedApplication.delegate;
    if(delegate.isRunningTests)
        return;
    
    NSWindow *window = nil;
    if ([identifier isEqualToString:NSStringFromClass(self.class)])
    {

        window = [delegate AllocateNewMainWindow].window;
    }
    completionHandler(window, nil);
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
    
    [(AppDelegate*)NSApplication.sharedApplication.delegate RemoveMainWindow:self];
}

- (void)ApplySkin:(ApplicationSkin)_skin {
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(ApplySkin:)])
            [i ApplySkin:_skin];
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

- (void)DidBecomeKeyWindow {
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(DidBecomeKeyWindow)])
            [i DidBecomeKeyWindow];
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

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect
{
    rect.origin.y = NSHeight(window.frame) - TitleBarHeight() - 1;
    if([m_WindowState.back() respondsToSelector:@selector(Toolbar)])
    {
        MyToolbar *tb = m_WindowState.back().Toolbar;
        if(tb != nil && !tb.isHidden)
            rect.origin.y -= tb.bounds.size.height;
    }
    
	return rect;
}

- (void)RevealEntries:(chained_strings)_entries inPath:(const char*)_path {
    [m_PanelState RevealEntries:move(_entries) inPath:_path];
}

- (void) ResignAsWindowState:(id)_state
{
    assert(_state != m_PanelState);
    assert(m_WindowState.size() > 1);
    assert(m_WindowState.back() == _state);

    bool is_terminal_resigning = m_WindowState.back() == m_Terminal;
    
    if([m_WindowState.back() respondsToSelector:@selector(Resigned)])
        [m_WindowState.back() Resigned];
    m_WindowState.pop_back();
    
    self.window.contentView = m_WindowState.back().ContentView;
    [self.window makeFirstResponder:self.window.contentView];
    
    if([m_WindowState.back() respondsToSelector:@selector(Assigned)])
        [m_WindowState.back() Assigned];
    
#if 0
    if(m_WindowState.back() == m_PanelState && is_terminal_resigning)
    {
        // here we need to synchonize cwd in terminal and cwd in active file panel
        char termcwd[MAXPATHLEN];
        if([m_Terminal GetCWD:termcwd])
            [[m_PanelState ActivePanelController] GoToGlobalHostsPathAsync:termcwd select_entry:NULL];
    }
#endif
}

- (void) PushNewWindowState:(NSObject<MainWindowStateProtocol> *)_state
{
    m_WindowState.push_back(_state);
    self.window.contentView = m_WindowState.back().ContentView;
    [self.window makeFirstResponder:self.window.contentView];
    
    if([m_WindowState.back() respondsToSelector:@selector(Assigned)])
        [m_WindowState.back() Assigned];
}

- (OperationsController*) OperationsController
{
    return m_PanelState.OperationsController;
}

- (void) RequestBigFileView:(string)_filepath with_fs:(shared_ptr<VFSHost>) _host
{
    if(!m_BigFileViewLoadingQ->Empty())
        return;
    
    m_BigFileViewLoadingQ->Run(^{
        auto frame = [self.window.contentView frame];
        MainWindowBigFileViewState *state = [[MainWindowBigFileViewState alloc] initWithFrame:frame];
        
        if([state OpenFile:_filepath.c_str() with_fs:_host])
            dispatch_to_main_queue(^{
                [self PushNewWindowState:state];
            });
    });
}

- (void)RequestTerminal:(const char*)_cwd;
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
        [m_Terminal ChDir:_cwd];
    }
}

- (void)RequestTerminalExecution:(const char*)_filename at:(const char*)_cwd
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
    }
    [m_Terminal Execute:_filename at:_cwd];
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

@end
