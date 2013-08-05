
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

@class QLPreviewPanel;

@implementation MainWindowController
{
    std::vector<MainWindowBigFileViewState *> m_WindowState; // .back is current state
    MainWindowFilePanelState    *m_BaseWindowState;
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
    
    m_BaseWindowState = [[MainWindowFilePanelState alloc] initWithFrame: [[[self window] contentView] frame]];
    [self PushNewWindowState:(MainWindowBigFileViewState*)m_BaseWindowState];
    
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
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(WindowWillClose)])
            [i WindowWillClose];

    [[self window] setContentView:nil];
    [[self window] makeFirstResponder:nil];
    
    while(!m_WindowState.empty())
    {
        [m_WindowState.back() Resigned];
        m_WindowState.pop_back();
    }
    m_BaseWindowState = nil;
    
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
            if(![*i WindowShouldClose:sender])
                return false;
    return true;
}

- (void)DidBecomeKeyWindow {
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(DidBecomeKeyWindow)])
            [i DidBecomeKeyWindow];
}

- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long)_ticket {
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(FireDirectoryChanged:ticket:)])
            [i FireDirectoryChanged:_dir ticket:_ticket];
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
    [m_BaseWindowState RevealEntries:_entries inPath:_path];
}

// Quick Look panel support
- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel {
    return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel {
    [QuickPreview UpdateData];
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel {
}

- (void) ResignAsWindowState:(id)_state
{
    assert(_state != m_BaseWindowState);
    assert(m_WindowState.size() > 1);
    assert(m_WindowState.back() == _state);
    
    [m_WindowState.back() Resigned];
    m_WindowState.pop_back();
    
    [[self window] setContentView:[m_WindowState.back() ContentView]];
    [[self window] makeFirstResponder: [[self window] contentView]];
    [m_WindowState.back() Assigned];    
}

- (void) PushNewWindowState:(MainWindowBigFileViewState *)_state
{
    m_WindowState.push_back(_state);
    [[self window] setContentView:[m_WindowState.back() ContentView]];
    [[self window] makeFirstResponder: [[self window] contentView]];
    
    [m_WindowState.back() Assigned];
}

- (OperationsController*) OperationsController
{
    return m_BaseWindowState.OperationsController;
}

- (void) RequestBigFileView:(const char*) _filepath
{
    MainWindowBigFileViewState *state = [[MainWindowBigFileViewState alloc] initWithFrame:[[[self window] contentView] frame]];
    if([state OpenFile:_filepath])
        [self PushNewWindowState:state];
}

- (void)OnApplicationWillTerminate
{
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(OnApplicationWillTerminate)])
            [i OnApplicationWillTerminate];
}

@end
