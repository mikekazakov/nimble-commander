//
//  FavoritesWindowController.h
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 3/15/17.
//  Copyright © 2017 Michael G. Kazakov. All rights reserved.
//

#pragma once

class FavoriteLocationsStorage;

@interface FavoritesWindowController :NSWindowController
    <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>

- (id) initWithFavoritesStorage:(function<FavoriteLocationsStorage&()>)_favorites_storage;

- (void) show;

@end
