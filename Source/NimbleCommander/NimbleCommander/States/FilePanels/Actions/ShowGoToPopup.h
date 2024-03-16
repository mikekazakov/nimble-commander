// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

#include <vector>

class NetworkConnectionsManager;
@class GoToPopupListActionMediator;

namespace nc::utility {
class NativeFSManager;
}

namespace nc::panel::actions {

// external dependencies:   AppDelegate.me.favoriteLocationsStorage
//                          AppDelegate.me.mainWindowControllers
//                          GlobalConfig

struct GoToPopupsBase {
    GoToPopupsBase(NetworkConnectionsManager &_net_mgr, nc::utility::NativeFSManager &_native_fs_mgr);

protected:
    std::tuple<NSMenu *, GoToPopupListActionMediator *>
    BuidInitialMenu(MainWindowFilePanelState *_state, PanelController *_panel, NSString *_title) const;
    NSMenu *BuildConnectionsQuickList(PanelController *_panel) const;
    NSMenu *BuildFavoritesQuickList(PanelController *_panel) const;
    NSMenu *BuildHistoryQuickList(PanelController *_panel) const;
    NSMenu *BuildParentFoldersQuickList(PanelController *_panel) const;
    NSMenu *BuildVolumesQuickList(PanelController *_panel) const;
    NSMenu *BuildGoToMenu(MainWindowFilePanelState *_state, PanelController *_panel) const;

    NetworkConnectionsManager &m_NetMgr;
    nc::utility::NativeFSManager &m_NativeFSMgr;
};

struct ShowLeftGoToPopup final : StateAction, GoToPopupsBase {
    ShowLeftGoToPopup(NetworkConnectionsManager &_net_mgr, nc::utility::NativeFSManager &_native_fs_mgr);
    virtual void Perform(MainWindowFilePanelState *_target, id _sender) const override;
};

struct ShowRightGoToPopup final : StateAction, GoToPopupsBase {
    ShowRightGoToPopup(NetworkConnectionsManager &_net_mgr, nc::utility::NativeFSManager &_native_fs_mgr);
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
};

struct ShowConnectionsQuickList final : PanelAction, GoToPopupsBase {
    ShowConnectionsQuickList(NetworkConnectionsManager &_net_mgr, nc::utility::NativeFSManager &_native_fs_mgr);
    void Perform(PanelController *_target, id _sender) const override;
};

struct ShowFavoritesQuickList final : PanelAction, GoToPopupsBase {
    ShowFavoritesQuickList(NetworkConnectionsManager &_net_mgr, nc::utility::NativeFSManager &_native_fs_mgr);
    void Perform(PanelController *_target, id _sender) const override;
};

struct ShowVolumesQuickList final : PanelAction, GoToPopupsBase {
    ShowVolumesQuickList(NetworkConnectionsManager &_net_mgr, nc::utility::NativeFSManager &_native_fs_mgr);
    void Perform(PanelController *_target, id _sender) const override;
};

struct ShowParentFoldersQuickList final : PanelAction, GoToPopupsBase {
    ShowParentFoldersQuickList(NetworkConnectionsManager &_net_mgr, nc::utility::NativeFSManager &_native_fs_mgr);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ShowHistoryQuickList final : PanelAction, GoToPopupsBase {
    ShowHistoryQuickList(NetworkConnectionsManager &_net_mgr, nc::utility::NativeFSManager &_native_fs_mgr);
    void Perform(PanelController *_target, id _sender) const override;
};

} // namespace nc::panel::actions
