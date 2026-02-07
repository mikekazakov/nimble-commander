// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Panel/PanelDataSortMode.h>
#include "PanelViewHeaderTheme.h"

@interface NCPanelViewHeader : NSView <NSTextFieldDelegate>

- (id)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (id)initWithFrame:(NSRect)frameRect theme:(std::unique_ptr<nc::panel::HeaderTheme>)_theme;

// Updates header title according to the new path. Should be called by controller when path is changed.
- (void)setPath:(NSString *)_path;

// Progress indicator located in the header. Shown only when displaying activity.
@property(nonatomic, readonly) NSProgressIndicator *busyIndicator;

// Search field located in the header. Hidden when not searching.
@property(nonatomic) NSString *searchPrompt;

// Number of matches for the current search query. Should be set by controller when search query is changed.
@property(nonatomic) int searchMatches;

// Sort mode for the panel. Displayed in a down-down button.
@property(nonatomic) nc::panel::data::SortMode sortMode;

// Called by the view when sort mode is changed by user via sort mode button in header.
@property(nonatomic) std::function<void(nc::panel::data::SortMode)> sortModeChangeCallback;

// Called by the view when search query is changed by user via search field in header.
// When the argument is nil this should be interpreted as discarding the search via (X) or Esc button.
@property(nonatomic) std::function<void(NSString *_query)> searchRequestChangeCallback;

// Updates the look of the header depending on the parent panel being active or not.
@property(nonatomic) bool active;

// Used to return the focus when search field is dismissed.
@property(nonatomic, weak) NSResponder *defaultResponder;

@end
