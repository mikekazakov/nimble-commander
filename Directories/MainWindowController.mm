
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
#import "PreferencesWindowController.h"
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
        
    [(AppDelegate*)[NSApp delegate] RemoveMainWindow:self];
}

- (void)ApplySkin:(ApplicationSkin)_skin {
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(ApplySkin:)])
            [i ApplySkin:_skin];
}

- (void)OnSkinSettingsChanged {
    for(auto i: m_WindowState)
        if([i respondsToSelector:@selector(SkinSettingsChanged)])
            [i SkinSettingsChanged];
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

- (void)OnPreferencesCommand:(id)sender {
    [PreferencesWindowController ShowWindow];
}

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet
       usingRect:(NSRect)rect
{
    // TODO: refactor me
    NSRect field_rect = [self.SheetAnchorLine frame];
    field_rect.origin.y += 2;
    field_rect.size.height = 0;
    return field_rect;
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

@end
