// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <functional>
#include <optional>

#include <Panel/PanelDataSortMode.h>
#include "NCPanelPathBarTypes.h"
#include "PanelViewHeaderTheme.h"

NS_ASSUME_NONNULL_BEGIN

@interface NCPanelViewHeader : NSView <NSTextFieldDelegate>

- (id)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (id)initWithFrame:(NSRect)frameRect theme:(std::unique_ptr<nc::panel::HeaderTheme>)_theme;

// Panel directory changed; plain title or breadcrumbs depending on wirePathBar.
- (void)setPath:(NSString *)path;

// One-time after PanelView exists; then setPath: can show breadcrumbs.
- (void)wirePathBarWithContextSource:(std::function<std::optional<nc::panel::PanelPathContext>(void)>)context_source
                   navigationHandler:(std::function<void(const std::string &)>)navigation_handler
                   contextMenuAction:(nc::panel::NCPanelPathBarContextMenuAction)context_menu_action;

@property(nonatomic, readonly) NSProgressIndicator *busyIndicator;

@property(nonatomic, nullable) NSString *searchPrompt;

@property(nonatomic) int searchMatches;

@property(nonatomic) nc::panel::data::SortMode sortMode;

@property(nonatomic) std::function<void(nc::panel::data::SortMode)> sortModeChangeCallback;

// nil means clear search (X or Esc).
@property(nonatomic) std::function<void(NSString *_Nullable _query)> searchRequestChangeCallback;

@property(nonatomic) bool active;

@property(nonatomic, weak, nullable) NSResponder *defaultResponder;

@end

NS_ASSUME_NONNULL_END
