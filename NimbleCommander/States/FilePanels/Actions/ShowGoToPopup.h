// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

// external dependencies:   AppDelegate.me.favoriteLocationsStorage
//                          AppDelegate.me.mainWindowControllers
//                          NativeFSManager::Instance()
//                          NetworkConnectionsManager::Instance()
//                          GlobalConfig

struct ShowLeftGoToPopup final : StateAction
{
    void Perform( MainWindowFilePanelState *_target, id _sender ) const override;
};

struct ShowRightGoToPopup final : StateAction
{
    void Perform( MainWindowFilePanelState *_target, id _sender ) const override;
};

struct ShowConnectionsQuickList final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ShowFavoritesQuickList final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ShowVolumesQuickList final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ShowParentFoldersQuickList final : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ShowHistoryQuickList final : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

}
