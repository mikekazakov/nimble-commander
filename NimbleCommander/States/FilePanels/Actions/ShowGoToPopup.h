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

struct ShowConnectionsQuickList : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

struct ShowFavoritesQuickList : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

struct ShowVolumesQuickList : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

struct ShowParentFoldersQuickList : DefaultPanelAction
{
    // TODO: predicate!
    static void Perform( PanelController *_target, id _sender );
};

struct ShowHistoryQuickList : DefaultPanelAction
{
    static void Perform( PanelController *_target, id _sender );
};

}
