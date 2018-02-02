// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.

#include "TabsManagement.h"
#include "../MainWindowFilePanelState.h"
#include "../MainWindowFilePanelState+TabsSupport.h"
#include "../Views/FilePanelMainSplitView.h"

namespace nc::panel::actions {

static const auto g_CloseTab =
    NSLocalizedString(@"Close Tab", "Menu item title for closing current tab");
static const auto g_CloseWindow =
    NSLocalizedString(@"Close Window", "Menu item title for closing current window");

bool ShowNextTab::Predicate( MainWindowFilePanelState *_target ) const
{
    return _target.currentSideTabsCount > 1;
}

bool ShowNextTab::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item ) const
{
    return Predicate( _target );
}

void ShowNextTab::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    [_target selectNextFilePanelTab];
}

bool ShowPreviousTab::Predicate( MainWindowFilePanelState *_target ) const
{
    return _target.currentSideTabsCount > 1;
}

bool ShowPreviousTab::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item ) const
{
    return Predicate( _target );
}

void ShowPreviousTab::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    [_target selectPreviousFilePanelTab];
}
    
bool CloseTab::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item ) const
{
    const auto tabs = _target.currentSideTabsCount;
    if( tabs == 0 ) {
        // in this case (no other adequate responders) - pass validation  up
        NSResponder *resp = _target;
        while( (resp = resp.nextResponder) )
            if( [resp respondsToSelector:_item.action] &&
                [resp respondsToSelector:@selector(validateMenuItem:)] )
                return [resp validateMenuItem:_item];
        return true;
    }
    _item.title = tabs > 1 ? g_CloseTab : g_CloseWindow;
    return Predicate(_target);
}
    
void CloseTab::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    const auto act_pc = _target.activePanelController;
    int tabs = 0;
    if( [_target isLeftController:act_pc] )
        tabs = _target.splitView.leftTabbedHolder.tabsCount;
    else if( [_target isRightController:act_pc] )
        tabs = _target.splitView.rightTabbedHolder.tabsCount;
    
    if( tabs > 1 )
        [_target closeTabForController:act_pc];
    else
        [_target.window performClose:_sender];
}
    
bool CloseWindow::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item ) const
{
    _item.hidden = _target.currentSideTabsCount < 2;
    return Predicate(_target);
}
    
void CloseWindow::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    [_target.window performClose:_sender];
}

void AddNewTab::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    const auto active_pc = _target.activePanelController;
    if( !active_pc )
        return;
    
    NSTabView *target_tab_view = nil;
    
    if( active_pc == _target.leftPanelController )
        target_tab_view = _target.splitView.leftTabbedHolder.tabView;
    else if( active_pc == _target.rightPanelController )
        target_tab_view = _target.splitView.rightTabbedHolder.tabView;
    
    if( !target_tab_view )
        return;
    
    [_target addNewTabToTabView:target_tab_view];
}

context::AddNewTab::AddNewTab(PanelController *_current_pc):
    m_CurrentPC(_current_pc)
{
}
    
void context::AddNewTab::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    NSTabView *target_tab_view = nil;
    
    if( [_target isLeftController:m_CurrentPC] )
        target_tab_view = _target.splitView.leftTabbedHolder.tabView;
    else if( [_target isRightController:m_CurrentPC] )
        target_tab_view = _target.splitView.rightTabbedHolder.tabView;
    
    if( !target_tab_view )
        return;
    
    [_target addNewTabToTabView:target_tab_view];
}
    
context::CloseTab::CloseTab(PanelController *_current_pc):
    m_CurrentPC(_current_pc)
{
}

bool context::CloseTab::Predicate( MainWindowFilePanelState *_target ) const
{
    if( [_target isLeftController:m_CurrentPC] )
        return _target.leftControllers.size() > 1;
    if( [_target isRightController:m_CurrentPC] )
        return _target.rightControllers.size() > 1;
    return false;
}

void context::CloseTab::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    [_target closeTabForController:m_CurrentPC];
}
    
context::CloseOtherTabs::CloseOtherTabs(PanelController *_current_pc):
    m_CurrentPC(_current_pc)
{
}

bool context::CloseOtherTabs::Predicate( MainWindowFilePanelState *_target ) const
{
    if( [_target isLeftController:m_CurrentPC] )
        return _target.leftControllers.size() > 1;
    if( [_target isRightController:m_CurrentPC] )
        return _target.rightControllers.size() > 1;
    return false;
}
    
void context::CloseOtherTabs::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    [_target closeOtherTabsForController:m_CurrentPC];
}
    
}
