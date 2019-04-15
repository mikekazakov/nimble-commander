#pragma once

#include <Cocoa/Cocoa.h>
@class NCViewerTextModeView;

@protocol NCViewerTextModeViewDelegate <NSObject>

/**
 * Returns a VFS error code.
 */
- (int) textModeView:(NCViewerTextModeView*)_view
    requestsSyncBackendWindowMovementAt:(int64_t)_position;

- (void) textModeView:(NCViewerTextModeView*)_view
    didScrollAtGlobalBytePosition:(int64_t)_position
    withScrollerPosition:(double)_scroller_position;

/**
 * Returns a range of selected bytes within the entire file.
 */
- (CFRange) textModeViewProvideSelection:(NCViewerTextModeView*)_view;

/**
 * Called by the view to change the selection.
 * '_selection' represents the selected bytes range within the entire file.
 */
- (void) textModeView:(NCViewerTextModeView*)_view
         setSelection:(CFRange)_selection;

/**
 * Returns the current line wrapping setting.
 */
- (bool) textModeViewProvideLineWrapping:(NCViewerTextModeView*)_view;

@end
