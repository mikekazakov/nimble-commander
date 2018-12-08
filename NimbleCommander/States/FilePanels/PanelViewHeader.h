// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelDataSortMode.h"
#include "PanelViewHeaderTheme.h"

@interface NCPanelViewHeader : NSView<NSSearchFieldDelegate>

- (id) initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (id) initWithFrame:(NSRect)frameRect
               theme:(std::unique_ptr<nc::panel::HeaderTheme>)_theme;

- (void) setPath:(NSString*)_path;

@property (nonatomic, readonly) NSProgressIndicator *busyIndicator;
@property (nonatomic) NSString *searchPrompt;
@property (nonatomic) int       searchMatches;
@property (nonatomic) nc::panel::data::SortMode sortMode;
@property (nonatomic) std::function<void(nc::panel::data::SortMode)> sortModeChangeCallback;

/**
 * Calling with nil means discarding the search via (X) button.
 */
@property (nonatomic) std::function<void(NSString*)> searchRequestChangeCallback;

@property (nonatomic) bool active;

@property (nonatomic, weak) NSResponder* defaultResponder;

@end
