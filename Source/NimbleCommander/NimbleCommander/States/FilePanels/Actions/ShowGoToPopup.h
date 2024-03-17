// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

#include <vector>

class NetworkConnectionsManager;
@class GoToPopupListActionMediator;

namespace nc::utility {
class NativeFSManager;
}

namespace nc::panel {
class TagsStorage;
}

namespace nc::panel::actions {

// external dependencies:   AppDelegate.me.favoriteLocationsStorage
//                          AppDelegate.me.mainWindowControllers
//                          GlobalConfig

struct GoToPopupsBase {
    GoToPopupsBase(NetworkConnectionsManager &_net_mgr,
                   nc::utility::NativeFSManager &_native_fs_mgr,
                   const nc::panel::TagsStorage &_tags_storage);

protected:
    std::tuple<NSMenu *, GoToPopupListActionMediator *>
    BuidInitialMenu(MainWindowFilePanelState *_state, PanelController *_panel, NSString *_title) const;
    NSMenu *BuildConnectionsQuickList(PanelController *_panel) const;
    NSMenu *BuildFavoritesQuickList(PanelController *_panel) const;
    NSMenu *BuildHistoryQuickList(PanelController *_panel) const;
    NSMenu *BuildParentFoldersQuickList(PanelController *_panel) const;
    NSMenu *BuildVolumesQuickList(PanelController *_panel) const;
    NSMenu *BuildTagsQuickList(PanelController *_panel) const;
    NSMenu *BuildGoToMenu(MainWindowFilePanelState *_state, PanelController *_panel) const;

    NetworkConnectionsManager &m_NetMgr;
    nc::utility::NativeFSManager &m_NativeFSMgr;
    const nc::panel::TagsStorage &m_Tags;
};

struct ShowLeftGoToPopup final : StateAction, GoToPopupsBase {
    using GoToPopupsBase::GoToPopupsBase;
    virtual void Perform(MainWindowFilePanelState *_target, id _sender) const override;
};

struct ShowRightGoToPopup final : StateAction, GoToPopupsBase {
    using GoToPopupsBase::GoToPopupsBase;
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
};

struct ShowConnectionsQuickList final : PanelAction, GoToPopupsBase {
    using GoToPopupsBase::GoToPopupsBase;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ShowFavoritesQuickList final : PanelAction, GoToPopupsBase {
    using GoToPopupsBase::GoToPopupsBase;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ShowVolumesQuickList final : PanelAction, GoToPopupsBase {
    using GoToPopupsBase::GoToPopupsBase;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ShowParentFoldersQuickList final : PanelAction, GoToPopupsBase {
    using GoToPopupsBase::GoToPopupsBase;
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ShowHistoryQuickList final : PanelAction, GoToPopupsBase {
    using GoToPopupsBase::GoToPopupsBase;
    void Perform(PanelController *_target, id _sender) const override;
};

struct ShowTagsQuickList final : PanelAction, GoToPopupsBase {
    using GoToPopupsBase::GoToPopupsBase;
    void Perform(PanelController *_target, id _sender) const override;
    // TODO: should be valid only if enabled in the settings
    // bool Predicate(PanelController *_target) const override;
};

} // namespace nc::panel::actions
