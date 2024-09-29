// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

#include <vector>

@class GoToPopupListActionMediator;
@class NCCommandPopover;
@class NCCommandPopoverItem;

namespace nc::config {
class Config;
}

namespace nc::utility {
class NativeFSManager;
}

namespace nc::panel {
class TagsStorage;
class NetworkConnectionsManager;
} // namespace nc::panel

namespace nc::panel::actions {

// external dependencies:   AppDelegate.me.favoriteLocationsStorage
//                          AppDelegate.me.mainWindowControllers
//                          GlobalConfig

struct GoToPopupsBase {
    GoToPopupsBase(NetworkConnectionsManager &_net_mgr,
                   nc::utility::NativeFSManager &_native_fs_mgr,
                   const nc::panel::TagsStorage &_tags_storage);

protected:
    std::pair<NCCommandPopover *, GoToPopupListActionMediator *>
    BuidInitialPopover(MainWindowFilePanelState *_state, PanelController *_panel, NSString *_title) const;
    std::pair<NCCommandPopover *, GoToPopupListActionMediator *>
    BuildConnectionsQuickList(PanelController *_panel) const;
    std::pair<NCCommandPopover *, GoToPopupListActionMediator *> BuildFavoritesQuickList(PanelController *_panel) const;
    std::pair<NCCommandPopover *, GoToPopupListActionMediator *> BuildHistoryQuickList(PanelController *_panel) const;
    std::pair<NCCommandPopover *, GoToPopupListActionMediator *>
    BuildParentFoldersQuickList(PanelController *_panel) const;
    std::pair<NCCommandPopover *, GoToPopupListActionMediator *> BuildVolumesQuickList(PanelController *_panel) const;
    std::pair<NCCommandPopover *, GoToPopupListActionMediator *> BuildTagsQuickList(PanelController *_panel) const;
    std::pair<NCCommandPopover *, GoToPopupListActionMediator *> BuildGoToMenu(MainWindowFilePanelState *_state,
                                                                               PanelController *_panel) const;

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
    ShowTagsQuickList(NetworkConnectionsManager &_net_mgr,
                      nc::utility::NativeFSManager &_native_fs_mgr,
                      const nc::panel::TagsStorage &_tags_storage,
                      const nc::config::Config &_config);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    const nc::config::Config &m_Config;
};

} // namespace nc::panel::actions
