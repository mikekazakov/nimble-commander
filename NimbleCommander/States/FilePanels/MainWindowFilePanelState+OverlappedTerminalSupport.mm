// Copyright (C) 2015-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "MainWindowFilePanelState+OverlappedTerminalSupport.h"
#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include "Views/FilePanelOverlappedTerminal.h"
#include "Views/FilePanelMainSplitView.h"
#include "PanelView.h"
#include "PanelViewKeystrokeSink.h"
#include "PanelController.h"
#include "PanelAux.h"
#include "PanelHistory.h"
#include <NimbleCommander/Bootstrap/Config.h>

using namespace nc::panel;
using namespace nc::term;
using namespace std::literals;

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
    return (s != ShellTask::TaskState::Inactive) &&
           (s != ShellTask::TaskState::Dead );
}

- (void) increaseBottomTerminalGap
{
    if( !m_OverlappedTerminal->terminal || self.isPanelsSplitViewHidden )
        return;
    m_OverlappedTerminal->bottom_gap++;
    m_OverlappedTerminal->bottom_gap = std::min(m_OverlappedTerminal->bottom_gap, m_OverlappedTerminal->terminal.totalScreenLines);
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
    m_OverlappedTerminal->bottom_gap = std::min(m_OverlappedTerminal->bottom_gap, m_OverlappedTerminal->terminal.totalScreenLines);
    if( m_OverlappedTerminal->bottom_gap > 0 )
        m_OverlappedTerminal->bottom_gap--;
    [self updateBottomConstraint];
    if(m_OverlappedTerminal->bottom_gap == 0)
        [self moveFocusBackToPanels];
}

- (void) activateOverlappedTerminal
{
    auto s = m_OverlappedTerminal->terminal.state;
    if( s == ShellTask::TaskState::Inactive || s == ShellTask::TaskState::Dead ) {
        std::string wd;
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
            auto r = std::make_shared<nc::panel::DirectoryChangeRequest>();
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
    m_SplitView.hidden = true;
}

- (void) showPanelsSplitView
{
    m_SplitView.hidden = false;
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
         m_OverlappedTerminal->terminal.state != ShellTask::TaskState::Shell )
        return;
    
    auto pc = self.activePanelController;
    if( !pc )
        pc = m_LastFocusedPanelController;
    if( pc && pc.vfs->IsNativeFS() )
        if( auto entry = pc.view.item ) {
            if( IsEligbleToTryToExecuteInConsole(entry) &&
                m_OverlappedTerminal->terminal.isShellVirgin )
                [m_OverlappedTerminal->terminal feedShellWithInput:"./"s + entry.Filename()];
            else
                [m_OverlappedTerminal->terminal feedShellWithInput:entry.Filename()];
        }
}

- (void) feedOverlappedTerminalWithFilenamesMenu
{
    if( !self.overlappedTerminalVisible ||
        m_OverlappedTerminal->terminal.state != ShellTask::TaskState::Shell )
        return;

    auto cpc = self.activePanelController;
    if( !cpc )
        cpc = m_LastFocusedPanelController;
    if( cpc ) {
        auto opc = cpc == self.leftPanelController ? self.rightPanelController : self.leftPanelController;
        
        std::vector<std::string> strings;
        auto add = [&](const std::string &_s) {
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

- (bool) executeInOverlappedTerminalIfPossible:(const std::string&)_filename
                                            at:(const std::string&)_path
{
    if( self.overlappedTerminalVisible &&
       m_OverlappedTerminal->terminal.state == ShellTask::TaskState::Shell &&
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
    return s == ShellTask::TaskState::ProgramInternal ||
           s == ShellTask::TaskState::ProgramExternal ;
}

- (int)bidForHandlingRoutedIntoOTKeyDown:(NSEvent *)_event;
{
    if( !self.overlappedTerminalVisible )
        return nc::panel::view::BiddingPriority::Skip;
    
    const auto keycode = _event.keyCode;
    if( keycode == 36 ) { // Return button
        if( m_OverlappedTerminal->terminal.state == ShellTask::TaskState::Shell &&
            m_OverlappedTerminal->terminal.isShellVirgin == false ) {
            // if user has entered something in overlapped terminal, then executing this stuff
            // via Enter should be in high priority
            return nc::panel::view::BiddingPriority::High;
        }
    }
    
    if( [m_OverlappedTerminal->terminal canFeedShellWithKeyDown:_event] )
        return nc::panel::view::BiddingPriority::Default;
    
    return nc::panel::view::BiddingPriority::Skip;
}

- (void)handleRoutedIntoOTKeyDown:(NSEvent *)_event;
{
    const auto keycode = _event.keyCode;
    if( keycode == 36 ) { // Return button
        if( m_OverlappedTerminal->terminal.state == ShellTask::TaskState::Shell &&
           m_OverlappedTerminal->terminal.isShellVirgin == false ) {
            [m_OverlappedTerminal->terminal commitShell];
            return;
        }
    }
    
    [m_OverlappedTerminal->terminal feedShellWithKeyDown:_event];
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
        m_OverlappedTerminal->bottom_gap = std::min(m_OverlappedTerminal->bottom_gap,
                                                    m_OverlappedTerminal->terminal.totalScreenLines);
        [self updateBottomConstraint];
        [self activateOverlappedTerminal];
    }
}

@end
