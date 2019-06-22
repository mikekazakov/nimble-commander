// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

#include <vector>

class NetworkConnectionsManager;
@class GoToPopupListActionMediator;

namespace nc::panel::actions {

// external dependencies:   AppDelegate.me.favoriteLocationsStorage
//                          AppDelegate.me.mainWindowControllers
//                          NativeFSManager::Instance()
//                          GlobalConfig

struct GoToPopupsBase
{
    GoToPopupsBase(NetworkConnectionsManager&_net_mgr);
protected:
    std::tuple<NSMenu*, GoToPopupListActionMediator*> BuidInitialMenu(MainWindowFilePanelState *_state,
                                                                 PanelController *_panel,
                                                                 NSString *_title) const;
    NSMenu *BuildConnectionsQuickList(PanelController *_panel) const;
    NSMenu *BuildFavoritesQuickList(PanelController *_panel) const;
    NSMenu *BuildHistoryQuickList(PanelController *_panel) const;
    NSMenu *BuildParentFoldersQuickList(PanelController *_panel) const;
    NSMenu *BuildVolumesQuickList(PanelController *_panel) const;
    NSMenu *BuildGoToMenu(MainWindowFilePanelState *_state, PanelController *_panel) const;
    
    NetworkConnectionsManager& m_NetMgr;
};
    
struct ShowLeftGoToPopup final : StateAction, GoToPopupsBase
{
    ShowLeftGoToPopup(NetworkConnectionsManager& _net_mgr,
                      SEL _right_popup_action);
    virtual void Perform( MainWindowFilePanelState *_target, id _sender ) const override;
private:
    SEL m_RightPopupAction;
};

struct ShowRightGoToPopup final : StateAction, GoToPopupsBase
{
    ShowRightGoToPopup(NetworkConnectionsManager&_net_mgr,
                       SEL _left_popup_action);
    void Perform( MainWindowFilePanelState *_target, id _sender ) const override;
private:
    SEL m_LeftPopupAction;
};

struct ShowConnectionsQuickList final : PanelAction, GoToPopupsBase
{
    ShowConnectionsQuickList(NetworkConnectionsManager&_net_mgr,
                             std::vector<SEL> _other_quick_lists);
    void Perform( PanelController *_target, id _sender ) const override;
private:
    std::vector<SEL> m_OtherQuickLists;    
};

struct ShowFavoritesQuickList final : PanelAction, GoToPopupsBase
{
    ShowFavoritesQuickList(NetworkConnectionsManager&_net_mgr,
                           std::vector<SEL> _other_quick_lists);
    void Perform( PanelController *_target, id _sender ) const override;
private:
    std::vector<SEL> m_OtherQuickLists;    
};

struct ShowVolumesQuickList final : PanelAction, GoToPopupsBase
{
    ShowVolumesQuickList(NetworkConnectionsManager&_net_mgr,
                         std::vector<SEL> _other_quick_lists);
    void Perform( PanelController *_target, id _sender ) const override;
private:
    std::vector<SEL> m_OtherQuickLists;    
};

struct ShowParentFoldersQuickList final : PanelAction, GoToPopupsBase
{
    ShowParentFoldersQuickList(NetworkConnectionsManager&_net_mgr,
                               std::vector<SEL> _other_quick_lists);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    std::vector<SEL> m_OtherQuickLists;    
};

struct ShowHistoryQuickList final : PanelAction, GoToPopupsBase
{
    ShowHistoryQuickList(NetworkConnectionsManager&_net_mgr,
                         std::vector<SEL> _other_quick_lists);
    void Perform( PanelController *_target, id _sender ) const override;
private:
    std::vector<SEL> m_OtherQuickLists;    
};

}
