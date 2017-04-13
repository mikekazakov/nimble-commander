#pragma once

#include "DefaultAction.h"

namespace panel::actions {

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
    void Perform( PanelController *_target, id _sender );
};

struct ShowFavoritesQuickList : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

struct ShowVolumesQuickList : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

struct ShowParentFoldersQuickList : PanelAction
{
    bool Predicate( PanelController *_target );
    void Perform( PanelController *_target, id _sender );
};

struct ShowHistoryQuickList : PanelAction
{
    void Perform( PanelController *_target, id _sender );
};

}
