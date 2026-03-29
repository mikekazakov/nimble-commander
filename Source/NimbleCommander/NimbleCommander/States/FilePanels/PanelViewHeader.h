// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <functional>
#include <optional>
#include <string>
#include <vector>

#include <Panel/PanelDataSortMode.h>
#include "PanelViewHeaderTheme.h"

namespace nc::panel {

/**
 * One visual segment in the directory path bar. When navigate_to_vfs_path is set, the segment is a link to that
 * absolute path on the current panel VFS. The last segment omits it and is shown as plain text (current folder).
 */
struct PanelHeaderBreadcrumb {
    NSString *_Nullable label = nil;
    std::optional<std::string> navigate_to_vfs_path;
};

} // namespace nc::panel

// NOLINTBEGIN(modernize-use-using, performance-enum-size)
// NS_ENUM(NSInteger, …) is the standard Obj-C export for this API; NSInteger width is intentional.
typedef NS_ENUM(NSInteger, NCPanelPathBarContextCommand) {
    NCPanelPathBarContextCommandOpen = 0,
    NCPanelPathBarContextCommandOpenInNewTab,
    NCPanelPathBarContextCommandCopyPath,
};
// NOLINTEND(modernize-use-using, performance-enum-size)

using NCPanelPathBarContextMenuActionBlock = void (^)(NSString *_Nonnull posixPath,
                                                      NCPanelPathBarContextCommand command);

NS_ASSUME_NONNULL_BEGIN

@interface NCPanelViewHeader : NSView <NSTextFieldDelegate, NSTextViewDelegate>

- (id)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (id)initWithFrame:(NSRect)frameRect theme:(std::unique_ptr<nc::panel::HeaderTheme>)_theme;

// Updates header title according to the new path. Should be called by controller when path is changed.
- (void)setPath:(NSString *)_path;

// Plain non-interactive title (e.g. temporary panel).
- (void)setPlainHeaderPath:(NSString *)_path;

// Clickable breadcrumbs.
// - fullPathForEditing is the full path string for read-only display (editable=NO) when the user opens
//   full-path mode from the last crumb or double-click outside the glyphs.
// - posixPathForActions is used by context actions when user clicks outside crumbs (must be a clean POSIX path
//   on the current VFS, without junction/prefix decorations).
- (void)setInteractiveBreadcrumbs:(const std::vector<nc::panel::PanelHeaderBreadcrumb> &)_breadcrumbs
               fullPathForEditing:(NSString *)_full_path_for_editing
              posixPathForActions:(NSString *)_posix_path_for_actions;

// Invoked when the user activates a breadcrumb (absolute path on the current VFS, always starts with '/').
@property(nonatomic) std::function<void(const std::string &)> pathNavigateToVFSPathCallback;

// Right-click path bar: Open / Open in New Tab / Copy Path (Marta-style). Optional.
@property(nonatomic, copy, nullable) NCPanelPathBarContextMenuActionBlock pathBarContextMenuAction;

// Progress indicator located in the header. Shown only when displaying activity.
@property(nonatomic, readonly) NSProgressIndicator *busyIndicator;

// Search field located in the header. Hidden when not searching.
@property(nonatomic, nullable) NSString *searchPrompt;

// Number of matches for the current search query. Should be set by controller when search query is changed.
@property(nonatomic) int searchMatches;

// Sort mode for the panel. Displayed in a down-down button.
@property(nonatomic) nc::panel::data::SortMode sortMode;

// Called by the view when sort mode is changed by user via sort mode button in header.
@property(nonatomic) std::function<void(nc::panel::data::SortMode)> sortModeChangeCallback;

// Called by the view when search query is changed by user via search field in header.
// When the argument is nil this should be interpreted as discarding the search via (X) or Esc button.
@property(nonatomic) std::function<void(NSString *_Nullable _query)> searchRequestChangeCallback;

// Updates the look of the header depending on the parent panel being active or not.
@property(nonatomic) bool active;

// Used to return the focus when search field is dismissed.
@property(nonatomic, weak, nullable) NSResponder *defaultResponder;

@end

NS_ASSUME_NONNULL_END
