// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::panel {
    class FavoriteLocationsStorage;
}

@interface FavoritesWindowController :NSWindowController
    <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>

- (id) initWithFavoritesStorage:
    (function<nc::panel::FavoriteLocationsStorage&()>)_favorites_storage;

- (void) show;

@end
