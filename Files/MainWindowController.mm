
//
//  MainWindowController.m
//  Directories
//
//  Created by Michael G. Kazakov on 09.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <vector>
#import "MainWindowController.h"
#import "AppDelegate.h"
#import "QuickPreview.h"
#import "BigFileView.h"
#import "MainWindowBigFileViewState.h"
#import "MainWindowFilePanelState.h"
#import "MainWindowTerminalState.h"
#import "PanelController.h"

@implementation MainWindowController
{
    vector<NSObject<MainWindowStateProtocol> *> m_WindowState; // .back is current state
    MainWindowFilePanelState    *m_PanelState;
    MainWindowTerminalState     *m_Terminal;
}

- (id)init {
    NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(100, 100, 1000, 600)
                                                   styleMask:NSResizableWindowMask|NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:false];
    window.minSize = NSMakeSize(660, 480);
    window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    [window setFrameUsingName:@"MainWindow"];

    if(self = [super initWithWindow:window]) {
        self.ShouldCascadeWindows = NO;
        window.title = @"Files αλφα ver.";
        window.Delegate = self;
        
        m_PanelState = [[MainWindowFilePanelState alloc] initWithFrame:[self.window.contentView frame]
                                                                Window:self.window];
        [self PushNewWindowState:m_PanelState];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(DidBecomeKeyWindow)
                                                     name:NSWindowDidBecomeKeyNotification
                                                   object:self.window];
    }
    
    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    assert(m_WindowState.empty());
}

- (void)windowDidResize:(NSNotification *)notification {
    
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(WindowDidResize)])
            [i WindowDidResize];
}

- (void)windowWillClose:(NSNotification *)notification {
//    NSLog(@"1! %ld", CFGetRetainCount((__bridge CFTypeRef)m_Terminal));
    
    
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(WindowWillClose)])
            [i WindowWillClose];

    [self.window setContentView:nil];
    [self.window makeFirstResponder:nil];
    
    while(!m_WindowState.empty())
    {
        if([m_WindowState.back() respondsToSelector:@selector(Resigned)])
            [m_WindowState.back() Resigned];
        
        m_WindowState.pop_back();
    }
    m_PanelState = nil;
    m_Terminal = nil;
    
    [(AppDelegate*)[NSApplication sharedApplication].delegate RemoveMainWindow:self];
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
    
    [[self window] setContentView:[m_WindowState.back() ContentView]];
    [[self window] makeFirstResponder: [[self window] contentView]];
    
    if([m_WindowState.back() respondsToSelector:@selector(Assigned)])
        [m_WindowState.back() Assigned];
    
    if(m_WindowState.back() == m_PanelState && is_terminal_resigning)
    {
        // here we need to synchonize cwd in terminal and cwd in active file panel
        char termcwd[MAXPATHLEN];
        if([m_Terminal GetCWD:termcwd])
            [[m_PanelState ActivePanelController] GoToGlobalHostsPathAsync:termcwd select_entry:NULL];
    }
}

- (void) PushNewWindowState:(NSObject<MainWindowStateProtocol> *)_state
{
    m_WindowState.push_back(_state);
    [[self window] setContentView:[m_WindowState.back() ContentView]];
    [[self window] makeFirstResponder: [[self window] contentView]];
    
    
    if([m_WindowState.back() respondsToSelector:@selector(Assigned)])
        [m_WindowState.back() Assigned];
}

- (OperationsController*) OperationsController
{
    return m_PanelState.OperationsController;
}

- (void) RequestBigFileView:(const char*) _filepath with_fs:(shared_ptr<VFSHost>) _host
{
    MainWindowBigFileViewState *state = [[MainWindowBigFileViewState alloc] initWithFrame:[[[self window] contentView] frame]];
    if([state OpenFile:_filepath with_fs:_host])
        [self PushNewWindowState:state];
}

- (void)OnApplicationWillTerminate
{
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(OnApplicationWillTerminate)])
            [i OnApplicationWillTerminate];
}

- (MainWindowFilePanelState*) FilePanelState
{
    return m_PanelState;
}

- (void)RequestTerminal:(const char*)_cwd;
{
    if(m_Terminal == nil)
    {
        MainWindowTerminalState *state = [[MainWindowTerminalState alloc] initWithFrame:[[[self window] contentView] frame]];
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
        MainWindowTerminalState *state = [[MainWindowTerminalState alloc] initWithFrame:[[[self window] contentView] frame]];
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

- (MainWindowTerminalState*) TerminalState
{
    return m_Terminal;
}

@end
