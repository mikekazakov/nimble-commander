//
//  MainWindowFilePanelState+OverlappedTerminalSupport.m
//  Files
//
//  Created by Michael G. Kazakov on 17/07/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState+OverlappedTerminalSupport.h"
#import "FilePanelOverlappedTerminal.h"
#import "FilePanelMainSplitView.h"
#import "PanelView.h"
#import "PanelController.h"

@implementation MainWindowFilePanelState (OverlappedTerminalSupport)

- (void) moveFocusToOverlappedTerminal
{
    if( self.isPanelActive )
        m_PreviouslyFocusedPanelController = self.activePanelController;
    [m_OverlappedTerminal focusTerminal];
}

- (void) moveFocusBackToPanels
{
    if( !self.isPanelActive) {
        if( auto p = (PanelController*)m_PreviouslyFocusedPanelController )
            [self ActivatePanelByController:p];
        else
            [self ActivatePanelByController:self.leftPanelController];
    }
    m_PreviouslyFocusedPanelController = nil;
}

- (bool) isOverlappedTerminalRunning
{
    if( !m_OverlappedTerminal )
        return false;
    auto s = m_OverlappedTerminal.state;
    return (s != TermShellTask::TaskState::Inactive) &&
           (s != TermShellTask::TaskState::Dead );
}

- (void) increaseBottomTerminalGap
{
    if( !m_OverlappedTerminal || self.isPanelsSplitViewHidden )
        return;
    m_OverlappedTerminalBottomGap++;
    m_OverlappedTerminalBottomGap = min(m_OverlappedTerminalBottomGap, m_OverlappedTerminal.totalScreenLines);
    [self frameDidChange];
    [self activateOverlappedTerminal];
    if(m_OverlappedTerminalBottomGap == 1) {
        [self moveFocusToOverlappedTerminal];
    }
}

- (void) decreaseBottomTerminalGap
{
    if( !m_OverlappedTerminal || self.isPanelsSplitViewHidden )
        return;
    if( m_OverlappedTerminalBottomGap == 0 )
        return;
    m_OverlappedTerminalBottomGap = min(m_OverlappedTerminalBottomGap, m_OverlappedTerminal.totalScreenLines);
    if( m_OverlappedTerminalBottomGap > 0 )
        m_OverlappedTerminalBottomGap--;
    [self frameDidChange];
    if(m_OverlappedTerminalBottomGap == 0)
        [self moveFocusBackToPanels];
}

- (void) activateOverlappedTerminal
{
    auto s = m_OverlappedTerminal.state;
    if( s == TermShellTask::TaskState::Inactive || s == TermShellTask::TaskState::Dead ) {
        string wd;
        if( auto p = self.activePanelController )
            if( p.vfs->IsNativeFS() )
                wd = p.currentDirectoryPath;
        
        [m_OverlappedTerminal runShell:wd];
        
        __weak MainWindowFilePanelState *weakself = self;
        m_OverlappedTerminal.onShellCWDChanged = [=]{
            if( MainWindowFilePanelState *strongself = weakself ) {
                auto pc = strongself.activePanelController;
                if( !pc )
                    pc = strongself->m_PreviouslyFocusedPanelController;
                if( pc ) {
                    auto cwd = strongself->m_OverlappedTerminal.cwd;
                    if( cwd != pc.currentDirectoryPath ) {
                        auto r = make_shared<PanelControllerGoToDirContext>();
                        r->RequestedDirectory = cwd;
                        r->VFS = VFSNativeHost::SharedHost();
                        [pc GoToDirWithContext:r];
                    }
                }
            }
        };
    }
}

- (void) hidePanelsSplitView
{
    [self activateOverlappedTerminal];
    [self moveFocusToOverlappedTerminal];
    m_MainSplitView.hidden = true;
}

- (void) showPanelsSplitView
{
    m_MainSplitView.hidden = false;
    [self moveFocusBackToPanels];
}

- (bool) overlappedTerminalVisible
{
    return m_OverlappedTerminal && m_OverlappedTerminalBottomGap > 0;
}

- (void) synchronizeOverlappedTerminalWithPanel:(PanelController*)_pc
{
    if( _pc.vfs->IsNativeFS() && self.overlappedTerminalVisible )
        [self synchronizeOverlappedTerminalCWD:_pc.currentDirectoryPath];
}

- (void) synchronizeOverlappedTerminalCWD:(const string&)_new_cwd
{
    if( m_OverlappedTerminal )
        [m_OverlappedTerminal changeWorkingDirectory:_new_cwd];
}

- (void) handleCtrlAltTab
{
    if( !self.overlappedTerminalVisible )
        return;
    
    if( self.isPanelActive )
       [self moveFocusToOverlappedTerminal];
    else
        [self moveFocusBackToPanels];
}

@end
