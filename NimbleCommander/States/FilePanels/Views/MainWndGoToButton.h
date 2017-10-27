// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>
#include <NimbleCommander/States/FilePanels/Favorites.h>

@class MainWindowFilePanelState;

@interface MainWndGoToButtonSelection : NSObject
@end

@interface MainWndGoToButtonSelectionFavorite : MainWndGoToButtonSelection
@property (nonatomic, readonly) const FavoriteLocationsStorage::Favorite &favorite;
@end

@interface MainWndGoToButtonSelectionVFSPath : MainWndGoToButtonSelection
@property string path;
@property VFSHostWeakPtr vfs;
@end

@interface MainWndGoToButtonSelectionSavedNetworkConnection : MainWndGoToButtonSelection
@property NetworkConnectionsManager::Connection connection;
@end

@interface MainWndGoToButton : NSPopUpButton<NSMenuDelegate>
@property (nonatomic) __weak MainWindowFilePanelState *owner;
@property (nonatomic) bool isRight;
@property (nonatomic, readonly) MainWndGoToButtonSelection *selection;

- (void) popUp;

+ (NSImage*) imageForLocation:(const PanelDataPersisency::Location &)_location;

@end
