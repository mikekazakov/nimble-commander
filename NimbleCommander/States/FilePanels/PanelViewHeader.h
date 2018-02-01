// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelDataSortMode.h"

@class NCPanelQuickSearch;

@interface PanelViewHeader : NSView<NSSearchFieldDelegate>

- (void) setPath:(NSString*)_path;

@property (nonatomic, readonly) NSProgressIndicator *busyIndicator;
@property (nonatomic) NSString *searchPrompt;
@property (nonatomic) int       searchMatches;
@property (nonatomic) nc::panel::data::SortMode sortMode;
@property (nonatomic) function<void(nc::panel::data::SortMode)> sortModeChangeCallback;
@property (nonatomic, weak) NCPanelQuickSearch *quickSearch;

@end
