// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <VFS/VFS_fwd.h>
#include <Cocoa/Cocoa.h>

namespace nc::panel {
class FavoriteLocationsStorage;
}

@interface FavoritesWindowController
    : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>

- (id)initWithFavoritesStorage:(std::function<nc::panel::FavoriteLocationsStorage &()>)_favorites_storage;

@property(nonatomic) std::function<std::vector<std::pair<VFSHostPtr, std::string>>()> provideCurrentUniformPaths;

- (void)show;

@end
