// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelDataSortMode.h"

@interface NCPanelViewHeader : NSView<NSSearchFieldDelegate>

- (void) setPath:(NSString*)_path;

@property (nonatomic, readonly) NSProgressIndicator *busyIndicator;
@property (nonatomic) NSString *searchPrompt;
@property (nonatomic) int       searchMatches;
@property (nonatomic) nc::panel::data::SortMode sortMode;
@property (nonatomic) function<void(nc::panel::data::SortMode)> sortModeChangeCallback;

/**
 * Calling with nil means discarding the search via (X) button.
 */
@property (nonatomic) function<void(NSString*)> searchRequestChangeCallback;

@end
