
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

@implementation MainWindowController
{
    std::vector<NSObject<MainWindowStateProtocol> *> m_WindowState; // .back is current state
    MainWindowFilePanelState    *m_PanelState;
    MainWindowTerminalState     *m_Terminal;
}

- (id)init {
    self = [super initWithWindowNibName:@"MainWindowController"];
    
    if (self) {
        [self setShouldCascadeWindows:NO];
        [self window]; // Force window to load.
    }
    
    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // TODO: data, controllers and view deletion. leaks now
    assert(m_WindowState.empty());
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [[self window] setDelegate:self];
    
    m_PanelState = [[MainWindowFilePanelState alloc] initWithFrame: [[[self window] contentView] frame]];
    [self PushNewWindowState:m_PanelState];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(DidBecomeKeyWindow)
                                                 name:NSWindowDidBecomeKeyNotification
                                               object:[self window]];
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

    [[self window] setContentView:nil];
    [[self window] makeFirstResponder:nil];
    
    while(!m_WindowState.empty())
    {
        if([m_WindowState.back() respondsToSelector:@selector(Resigned)])
            [m_WindowState.back() Resigned];
        
        m_WindowState.pop_back();
    }
    m_PanelState = nil;
    m_Terminal = nil;
    
    [(AppDelegate*)[NSApp delegate] RemoveMainWindow:self];
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

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect
{
    if([m_WindowState.back() respondsToSelector:@selector(window:willPositionSheet:usingRect:)])
        return [m_WindowState.back() window:window willPositionSheet:sheet usingRect:rect];
        
    return rect;
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

- (void)RevealEntries:(FlexChainedStringsChunk*)_entries inPath:(const char*)_path {
    [m_PanelState RevealEntries:_entries inPath:_path];
}

- (void) ResignAsWindowState:(id)_state
{
    assert(_state != m_PanelState);
    assert(m_WindowState.size() > 1);
    assert(m_WindowState.back() == _state);

    if([m_WindowState.back() respondsToSelector:@selector(Resigned)])
        [m_WindowState.back() Resigned];
    m_WindowState.pop_back();
    
    [[self window] setContentView:[m_WindowState.back() ContentView]];
    [[self window] makeFirstResponder: [[self window] contentView]];
    
    if([m_WindowState.back() respondsToSelector:@selector(Assigned)])
        [m_WindowState.back() Assigned];
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

- (void) RequestBigFileView:(const char*) _filepath with_fs:(std::shared_ptr<VFSHost>) _host
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
//        [m_Terminal ChDir:_cwd];
    }
    [m_Terminal Execute:_filename at:_cwd];
}

- (MainWindowTerminalState*) TerminalState
{
    return m_Terminal;
}

@end
