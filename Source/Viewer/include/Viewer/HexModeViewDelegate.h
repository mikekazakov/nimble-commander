// Copyright (C) 2019-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <Base/Error.h>

@class NCViewerHexModeView;

@protocol NCViewerHexModeViewDelegate <NSObject>

// ...
- (std::expected<void, nc::Error>)hexModeView:(NCViewerHexModeView *)_view
          requestsSyncBackendWindowMovementAt:(int64_t)_position;

- (void)hexModeView:(NCViewerHexModeView *)_view
    didScrollAtGlobalBytePosition:(int64_t)_position
             withScrollerPosition:(double)_scroller_position;

/**
 * Returns a range of selected bytes within the entire file.
 */
- (CFRange)hexModeViewProvideSelection:(NCViewerHexModeView *)_view;

/**
 * Called by the view to change the selection.
 * '_selection' represents the selected bytes range within the entire file.
 */
- (void)hexModeView:(NCViewerHexModeView *)_view setSelection:(CFRange)_selection;
//
///**
// * Returns the current line wrapping setting.
// */
//- (bool) textModeViewProvideLineWrapping:(NCViewerTextModeView*)_view;

@end
