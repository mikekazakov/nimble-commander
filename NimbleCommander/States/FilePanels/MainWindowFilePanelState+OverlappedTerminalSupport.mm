//
//  MainWindowFilePanelState+OverlappedTerminalSupport.m
//  Files
//
//  Created by Michael G. Kazakov on 17/07/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include "MainWindowFilePanelState+OverlappedTerminalSupport.h"
#include "Views/FilePanelOverlappedTerminal.h"
#include "Views/FilePanelMainSplitView.h"
#include "PanelView.h"
#include "PanelController.h"
#include "PanelAux.h"

static const auto g_ConfigGapPath =  "filePanel.general.bottomGapForOverlappedTerminal";

@implementation MainWindowFilePanelState (OverlappedTerminalSupport)

- (void) moveFocusToOverlappedTerminal
{
    if( self.isPanelActive )
        m_LastFocusedPanelController = self.activePanelController;
    [m_OverlappedTerminal->terminal focusTerminal];
}

- (void) moveFocusBackToPanels
{
    if( !self.isPanelActive) {
        if( auto p = (PanelController*)m_LastFocusedPanelController )
            [self ActivatePanelByController:p];
        else
            [self ActivatePanelByController:self.leftPanelController];
    }
}

- (bool) isOverlappedTerminalRunning
{
    if( !m_OverlappedTerminal->terminal )
        return false;
    auto s = m_OverlappedTerminal->terminal.state;
    return (s != TermShellTask::TaskState::Inactive) &&
           (s != TermShellTask::TaskState::Dead );
}

- (void) increaseBottomTerminalGap
{
    if( !m_OverlappedTerminal->terminal || self.isPanelsSplitViewHidden )
        return;
    m_OverlappedTerminal->bottom_gap++;
    m_OverlappedTerminal->bottom_gap = min(m_OverlappedTerminal->bottom_gap, m_OverlappedTerminal->terminal.totalScreenLines);
    [self updateBottomConstraint];
    [self activateOverlappedTerminal];
    if(m_OverlappedTerminal->bottom_gap == 1) {
        [self moveFocusToOverlappedTerminal];
    }
}

- (void) decreaseBottomTerminalGap
{
    if( !m_OverlappedTerminal->terminal || self.isPanelsSplitViewHidden )
        return;
    if( m_OverlappedTerminal->bottom_gap == 0 )
        return;
    m_OverlappedTerminal->bottom_gap = min(m_OverlappedTerminal->bottom_gap, m_OverlappedTerminal->terminal.totalScreenLines);
    if( m_OverlappedTerminal->bottom_gap > 0 )
        m_OverlappedTerminal->bottom_gap--;
    [self updateBottomConstraint];
    if(m_OverlappedTerminal->bottom_gap == 0)
        [self moveFocusBackToPanels];
}

- (void) activateOverlappedTerminal
{
    auto s = m_OverlappedTerminal->terminal.state;
    if( s == TermShellTask::TaskState::Inactive || s == TermShellTask::TaskState::Dead ) {
        string wd;
        if( auto p = self.activePanelController )
            wd = p.history.LastNativeDirectoryVisited();
        
        [m_OverlappedTerminal->terminal runShell:wd];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
        __weak MainWindowFilePanelState *weakself = self;
        m_OverlappedTerminal->terminal.onShellCWDChanged = [=]{
            [(MainWindowFilePanelState*)weakself onOverlappedTerminalShellCWDChanged];
        };
        m_OverlappedTerminal->terminal.onLongTaskStarted = [=]{
            [(MainWindowFilePanelState*)weakself onOverlappedTerminalLongTaskStarted];
        };
        m_OverlappedTerminal->terminal.onLongTaskFinished = [=]{
            [(MainWindowFilePanelState*)weakself onOverlappedTerminalLongTaskFinished];
        };
#pragma clang diagnostic pop
    }
}

- (void) onOverlappedTerminalShellCWDChanged
{
    auto pc = self.activePanelController;
    if( !pc )
        pc = m_LastFocusedPanelController;
    if( pc ) {
        auto cwd = m_OverlappedTerminal->terminal.cwd;
        if( cwd != pc.currentDirectoryPath || !pc.vfs->IsNativeFS() ) {
            auto r = make_shared<PanelControllerGoToDirContext>();
            r->RequestedDirectory = cwd;
            r->VFS = VFSNativeHost::SharedHost();
            [pc GoToDirWithContext:r];
        }
    }
}

- (void)onOverlappedTerminalLongTaskStarted
{
    if( self.overlappedTerminalVisible && !self.isPanelsSplitViewHidden) {
        [self hidePanelsSplitView];
        m_OverlappedTerminal->did_hide_panels_for_long_task = true;
    }
}

- (void)onOverlappedTerminalLongTaskFinished
{
    if( self.isPanelsSplitViewHidden && m_OverlappedTerminal->did_hide_panels_for_long_task) {
        [self showPanelsSplitView];
        m_OverlappedTerminal->did_hide_panels_for_long_task = false;
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
    return m_OverlappedTerminal->terminal &&
        (m_OverlappedTerminal->bottom_gap > 0 || self.isPanelsSplitViewHidden);
}

- (void) synchronizeOverlappedTerminalWithPanel:(PanelController*)_pc
{
    if(_pc.isUniform &&
       _pc.vfs->IsNativeFS() &&
       self.overlappedTerminalVisible &&
       m_OverlappedTerminal->terminal.isShellVirgin == true )
        [m_OverlappedTerminal->terminal changeWorkingDirectory:_pc.currentDirectoryPath];
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


- (void) feedOverlappedTerminalWithCurrentFilename
{
    if( !self.overlappedTerminalVisible ||
         m_OverlappedTerminal->terminal.state != TermShellTask::TaskState::Shell )
        return;
    
    auto pc = self.activePanelController;
    if( !pc )
        pc = m_LastFocusedPanelController;
    if( pc && pc.vfs->IsNativeFS() )
        if( auto entry = pc.view.item ) {
            if( panel::IsEligbleToTryToExecuteInConsole(entry) &&
                m_OverlappedTerminal->terminal.isShellVirgin )
                [m_OverlappedTerminal->terminal feedShellWithInput:"./"s + entry.Name()];
            else
                [m_OverlappedTerminal->terminal feedShellWithInput:entry.Name()];
        }
}

- (void) feedOverlappedTerminalWithFilenamesMenu
{
    if( !self.overlappedTerminalVisible || m_OverlappedTerminal->terminal.state != TermShellTask::TaskState::Shell )
        return;

    auto cpc = self.activePanelController;
    if( !cpc )
        cpc = m_LastFocusedPanelController;
    if( cpc ) {
        auto opc = cpc == self.leftPanelController ? self.rightPanelController : self.leftPanelController;
        
        vector<string> strings;
        auto add = [&](const string &_s) {
            if(!_s.empty())
                strings.emplace_back(_s);
        };
        
        if( cpc.vfs->IsNativeFS() ) {
            add( cpc.currentFocusedEntryFilename );
            add( cpc.currentFocusedEntryPath );
        }
        if( opc.vfs->IsNativeFS() ) {
            add( opc.currentFocusedEntryFilename );
            add( opc.currentFocusedEntryPath );
        }
        
        if( !strings.empty() )
            [m_OverlappedTerminal->terminal runPasteMenu:strings];
    }
}

- (bool) handleReturnKeyWithOverlappedTerminal
{
    if( self.overlappedTerminalVisible &&
        m_OverlappedTerminal->terminal.state == TermShellTask::TaskState::Shell &&
        m_OverlappedTerminal->terminal.isShellVirgin == false ) {
        // dirty, dirty shell... lets clear it all with Return key
        [m_OverlappedTerminal->terminal commitShell];
        return true;
    }
    
    
    return false;
}

- (bool) executeInOverlappedTerminalIfPossible:(const string&)_filename at:(const string&)_path
{
    if( self.overlappedTerminalVisible &&
       m_OverlappedTerminal->terminal.state == TermShellTask::TaskState::Shell &&
       m_OverlappedTerminal->terminal.isShellVirgin == true ) {
        // assumes that _filename is eligible to execute in terminal (should be check by PanelController before)
        [m_OverlappedTerminal->terminal feedShellWithInput:"./"s + _filename];
        [m_OverlappedTerminal->terminal commitShell];
        return true;
    }
    return false;
}

- (bool) isAnythingRunningInOverlappedTerminal
{
    if( !m_OverlappedTerminal->terminal )
        return false;
    auto s = m_OverlappedTerminal->terminal.state;
    return s == TermShellTask::TaskState::ProgramInternal ||
           s == TermShellTask::TaskState::ProgramExternal ;
}

- (bool) overlappedTerminalWillEatKeyDown:(NSEvent *)event
{
    if( !self.overlappedTerminalVisible )
        return false;
    
    return [m_OverlappedTerminal->terminal canFeedShellWithKeyDown:event];
}

- (bool) feedOverlappedTerminalWithKeyDown:(NSEvent *)event
{
    if( !self.overlappedTerminalVisible )
        return false;
    
    return [m_OverlappedTerminal->terminal feedShellWithKeyDown:event];
}

- (void) saveOverlappedTerminalSettings
{
    if( !m_OverlappedTerminal->terminal )
        return;
  
    GlobalConfig().Set(g_ConfigGapPath, m_OverlappedTerminal->bottom_gap);
}

- (void) loadOverlappedTerminalSettingsAndRunIfNecessary
{
    if( !m_OverlappedTerminal->terminal )
        return;
    int gap = GlobalConfig().GetInt( g_ConfigGapPath );
    if( gap > 0 ) {
        m_OverlappedTerminal->bottom_gap = gap;
        m_OverlappedTerminal->bottom_gap = min(m_OverlappedTerminal->bottom_gap, m_OverlappedTerminal->terminal.totalScreenLines);
        [self updateBottomConstraint];
        [self activateOverlappedTerminal];
    }
}

@end
