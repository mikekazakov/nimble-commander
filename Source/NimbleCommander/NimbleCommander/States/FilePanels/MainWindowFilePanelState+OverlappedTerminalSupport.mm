// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "MainWindowFilePanelState+OverlappedTerminalSupport.h"
#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include "Views/FilePanelOverlappedTerminal.h"
#include "Views/FilePanelMainSplitView.h"
#include "PanelView.h"
#include <Panel/PanelViewKeystrokeSink.h>
#include "PanelController.h"
#include "PanelAux.h"
#include "PanelHistory.h"
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/NativeVFSHostInstance.h>

using namespace nc::panel;
using namespace nc::term;
using namespace std::literals;

static const auto g_ConfigGapPath = "filePanel.general.bottomGapForOverlappedTerminal";

@implementation MainWindowFilePanelState (OverlappedTerminalSupport)

- (void)moveFocusToOverlappedTerminal
{
    if( self.isPanelActive )
        m_LastFocusedPanelController = self.activePanelController;
    [m_OverlappedTerminal->terminal focusTerminal];
}

- (void)moveFocusBackToPanels
{
    if( !self.isPanelActive ) {
        if( auto p = static_cast<PanelController *>(m_LastFocusedPanelController) )
            [self ActivatePanelByController:p];
        else
            [self ActivatePanelByController:self.leftPanelController];
    }
}

- (bool)isOverlappedTerminalRunning
{
    if( !m_OverlappedTerminal->terminal )
        return false;
    auto s = m_OverlappedTerminal->terminal.state;
    return (s != ShellTask::TaskState::Inactive) && (s != ShellTask::TaskState::Dead);
}

- (bool)canIncreaseBootomTerminalGap
{
    if( !m_OverlappedTerminal->terminal || self.isPanelsSplitViewHidden )
        return false;

    if( m_OverlappedTerminal->bottom_gap >= m_OverlappedTerminal->terminal.totalScreenLines )
        return false;

    return true;
}

- (void)increaseBottomTerminalGap
{
    if( !self.canIncreaseBootomTerminalGap )
        return;
    m_OverlappedTerminal->bottom_gap++;
    m_OverlappedTerminal->bottom_gap =
        std::min(m_OverlappedTerminal->bottom_gap, m_OverlappedTerminal->terminal.totalScreenLines);
    [self updateBottomConstraint];
    [self activateOverlappedTerminal];
    if( m_OverlappedTerminal->bottom_gap == 1 ) {
        [self moveFocusToOverlappedTerminal];
    }
}

- (bool)canDecreaseBottomTerminalGap
{
    if( !m_OverlappedTerminal->terminal || self.isPanelsSplitViewHidden )
        return false;
    if( m_OverlappedTerminal->bottom_gap == 0 )
        return false;
    return true;
}

- (void)decreaseBottomTerminalGap
{
    if( !m_OverlappedTerminal->terminal || self.isPanelsSplitViewHidden )
        return;
    if( m_OverlappedTerminal->bottom_gap == 0 )
        return;
    m_OverlappedTerminal->bottom_gap =
        std::min(m_OverlappedTerminal->bottom_gap, m_OverlappedTerminal->terminal.totalScreenLines);
    if( m_OverlappedTerminal->bottom_gap > 0 )
        m_OverlappedTerminal->bottom_gap--;
    [self updateBottomConstraint];
    if( m_OverlappedTerminal->bottom_gap == 0 )
        [self moveFocusBackToPanels];
}

- (void)activateOverlappedTerminal
{
    auto s = m_OverlappedTerminal->terminal.state;
    if( s == ShellTask::TaskState::Inactive || s == ShellTask::TaskState::Dead ) {
        std::string wd;
        if( auto p = self.activePanelController )
            wd = p.history.LastNativeDirectoryVisited();

        [m_OverlappedTerminal->terminal runShell:wd];

        __weak MainWindowFilePanelState *weakself = self;
        m_OverlappedTerminal->terminal.onShellCWDChanged = [=] {
            [static_cast<MainWindowFilePanelState *>(weakself) onOverlappedTerminalShellCWDChanged];
        };
        m_OverlappedTerminal->terminal.onLongTaskStarted = [=] {
            [static_cast<MainWindowFilePanelState *>(weakself) onOverlappedTerminalLongTaskStarted];
        };
        m_OverlappedTerminal->terminal.onLongTaskFinished = [=] {
            [static_cast<MainWindowFilePanelState *>(weakself) onOverlappedTerminalLongTaskFinished];
        };
    }
}

- (void)onOverlappedTerminalShellCWDChanged
{
    auto pc = self.activePanelController;
    if( !pc )
        pc = m_LastFocusedPanelController;
    if( pc ) {
        auto cwd = m_OverlappedTerminal->terminal.cwd;
        if( cwd != pc.currentDirectoryPath || !pc.vfs->IsNativeFS() ) {
            auto r = std::make_shared<nc::panel::DirectoryChangeRequest>();
            r->RequestedDirectory = cwd;
            r->VFS = nc::bootstrap::NativeVFSHostInstance().SharedPtr();
            [pc GoToDirWithContext:r];
        }
    }
}

- (void)onOverlappedTerminalLongTaskStarted
{
    if( self.overlappedTerminalVisible && !self.isPanelsSplitViewHidden ) {
        m_OverlappedTerminal->did_hide_panels_for_long_task = true;
        [self hidePanelsSplitView];
    }
}

- (void)onOverlappedTerminalLongTaskFinished
{
    if( self.isPanelsSplitViewHidden && m_OverlappedTerminal->did_hide_panels_for_long_task ) {
        m_OverlappedTerminal->did_hide_panels_for_long_task = false;
        [self showPanelsSplitView];
    }
}

- (void)hidePanelsSplitView
{
    [self activateOverlappedTerminal];
    m_SplitView.hidden = true;
    [self updateOverlappedTerminalVisibility];
    [self moveFocusToOverlappedTerminal];
}

- (void)showPanelsSplitView
{
    m_SplitView.hidden = false;
    [self updateOverlappedTerminalVisibility];
    [self moveFocusBackToPanels];
}

- (void)updateOverlappedTerminalVisibility
{
    if( m_OverlappedTerminal->terminal == nullptr )
        return;

    if( m_OverlappedTerminal->bottom_gap == 0 && !m_SplitView.hidden ) {
        m_OverlappedTerminal->terminal.hidden = true;
    }
    else {
        m_OverlappedTerminal->terminal.hidden = false;
    }

    if( m_OverlappedTerminal->did_hide_panels_for_long_task ) {
        m_OverlappedTerminal->terminal.termScrollView.nonOverlappedHeight =
            m_OverlappedTerminal->terminal.termScrollView.bounds.size.height;
    }
    else {
        const double gap = [m_OverlappedTerminal->terminal bottomGapForLines:m_OverlappedTerminal->bottom_gap];
        m_OverlappedTerminal->terminal.termScrollView.nonOverlappedHeight = gap;
    }
}

- (bool)overlappedTerminalVisible
{
    return m_OverlappedTerminal->terminal && (m_OverlappedTerminal->bottom_gap > 0 || self.isPanelsSplitViewHidden);
}

- (void)synchronizeOverlappedTerminalWithPanel:(PanelController *)_pc
{
    if( _pc.isUniform && _pc.vfs->IsNativeFS() && self.overlappedTerminalVisible &&
        m_OverlappedTerminal->terminal.isShellVirgin )
        [m_OverlappedTerminal->terminal changeWorkingDirectory:_pc.currentDirectoryPath];
}

- (void)handleCtrlAltTab
{
    if( !self.overlappedTerminalVisible )
        return;

    if( self.isPanelActive )
        [self moveFocusToOverlappedTerminal];
    else
        [self moveFocusBackToPanels];
}

- (void)feedOverlappedTerminalWithCurrentFilename
{
    if( !self.overlappedTerminalVisible || m_OverlappedTerminal->terminal.state != ShellTask::TaskState::Shell )
        return;

    auto pc = self.activePanelController;
    if( !pc )
        pc = m_LastFocusedPanelController;
    if( pc && pc.vfs->IsNativeFS() )
        if( auto entry = pc.view.item ) {
            if( IsEligbleToTryToExecuteInConsole(entry) && m_OverlappedTerminal->terminal.isShellVirgin )
                [m_OverlappedTerminal->terminal feedShellWithInput:"./"s + entry.Filename()];
            else
                [m_OverlappedTerminal->terminal feedShellWithInput:entry.Filename()];
        }
}

- (void)feedOverlappedTerminalWithFilenamesMenu
{
    if( !self.overlappedTerminalVisible || m_OverlappedTerminal->terminal.state != ShellTask::TaskState::Shell )
        return;

    auto cpc = self.activePanelController;
    if( !cpc )
        cpc = m_LastFocusedPanelController;
    if( cpc ) {
        auto opc = cpc == self.leftPanelController ? self.rightPanelController : self.leftPanelController;

        std::vector<std::string> strings;
        auto add = [&](const std::string &_s) {
            if( !_s.empty() )
                strings.emplace_back(_s);
        };

        if( cpc.vfs->IsNativeFS() ) {
            add(cpc.currentFocusedEntryFilename);
            add(cpc.currentFocusedEntryPath);
        }
        if( opc.vfs->IsNativeFS() ) {
            add(opc.currentFocusedEntryFilename);
            add(opc.currentFocusedEntryPath);
        }

        if( !strings.empty() )
            [m_OverlappedTerminal->terminal runPasteMenu:strings];
    }
}

- (bool)executeInOverlappedTerminalIfPossible:(const std::string &)_filename
                                           at:(const std::string &) [[maybe_unused]] _path
{
    if( self.overlappedTerminalVisible && m_OverlappedTerminal->terminal.state == ShellTask::TaskState::Shell &&
        m_OverlappedTerminal->terminal.isShellVirgin ) {
        // assumes that _filename is eligible to execute in terminal (should be check by PanelController before)
        [m_OverlappedTerminal->terminal feedShellWithInput:"./"s + _filename];
        [m_OverlappedTerminal->terminal commitShell];
        return true;
    }
    return false;
}

- (bool)isAnythingRunningInOverlappedTerminal
{
    if( !m_OverlappedTerminal->terminal )
        return false;
    auto s = m_OverlappedTerminal->terminal.state;
    return s == ShellTask::TaskState::ProgramInternal || s == ShellTask::TaskState::ProgramExternal;
}

- (int)bidForHandlingRoutedIntoOTKeyDown:(NSEvent *)_event
{
    if( !self.overlappedTerminalVisible )
        return nc::panel::view::BiddingPriority::Skip;

    const auto keycode = _event.keyCode;
    if( keycode == 36 ) { // Return button
        if( m_OverlappedTerminal->terminal.state == ShellTask::TaskState::Shell &&
            !m_OverlappedTerminal->terminal.isShellVirgin ) {
            // if user has entered something in overlapped terminal, then executing this stuff
            // via Enter should be in high priority
            return nc::panel::view::BiddingPriority::Max;
        }
    }

    if( [m_OverlappedTerminal->terminal canFeedShellWithKeyDown:_event] )
        return nc::panel::view::BiddingPriority::Default;

    return nc::panel::view::BiddingPriority::Skip;
}

- (void)handleRoutedIntoOTKeyDown:(NSEvent *)_event
{
    const auto keycode = _event.keyCode;
    if( keycode == 36 ) { // Return button
        if( m_OverlappedTerminal->terminal.state == ShellTask::TaskState::Shell &&
            !m_OverlappedTerminal->terminal.isShellVirgin ) {
            [m_OverlappedTerminal->terminal commitShell];
            return;
        }
    }

    [m_OverlappedTerminal->terminal feedShellWithKeyDown:_event];
}

- (void)saveOverlappedTerminalSettings
{
    if( !m_OverlappedTerminal->terminal )
        return;

    GlobalConfig().Set(g_ConfigGapPath, m_OverlappedTerminal->bottom_gap);
}

- (void)loadOverlappedTerminalSettingsAndRunIfNecessary
{
    if( !m_OverlappedTerminal->terminal )
        return;
    int gap = GlobalConfig().GetInt(g_ConfigGapPath);
    if( gap > 0 ) {
        m_OverlappedTerminal->bottom_gap = gap;
        m_OverlappedTerminal->bottom_gap =
            std::min(m_OverlappedTerminal->bottom_gap, m_OverlappedTerminal->terminal.totalScreenLines);
        [self updateBottomConstraint];
        [self activateOverlappedTerminal];
    }
}

@end
