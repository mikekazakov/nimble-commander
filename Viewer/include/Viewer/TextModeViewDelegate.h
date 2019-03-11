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

@end
