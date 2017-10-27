// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

class FavoriteLocationsStorage;

@interface FavoritesWindowController :NSWindowController
    <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>

- (id) initWithFavoritesStorage:(function<FavoriteLocationsStorage&()>)_favorites_storage;

- (void) show;

@end
