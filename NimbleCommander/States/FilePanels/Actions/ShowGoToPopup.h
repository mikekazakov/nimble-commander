// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

// external dependencies:   AppDelegate.me.favoriteLocationsStorage
//                          AppDelegate.me.mainWindowControllers
//                          NativeFSManager::Instance()
//                          NetworkConnectionsManager::Instance()
//                          GlobalConfig

struct ShowLeftGoToPopup : DefaultStateAction
{
    static void Perform( MainWindowFilePanelState *_target, id _sender );
};

struct ShowRightGoToPopup : DefaultStateAction
{
    static void Perform( MainWindowFilePanelState *_target, id _sender );
};

struct ShowConnectionsQuickList : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ShowFavoritesQuickList : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ShowVolumesQuickList : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ShowParentFoldersQuickList : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct ShowHistoryQuickList : PanelAction
{
    void Perform( PanelController *_target, id _sender ) const override;
};

}
