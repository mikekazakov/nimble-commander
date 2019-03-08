#pragma once

#include <Cocoa/Cocoa.h>
@class NCViewerTextModeView;

@protocol NCViewerTextModeViewDelegate <NSObject>

//    int MoveWindowSync(uint64_t _pos); // return VFS error code

/**
 * Returns a VFS error code.
 */
- (int) textModeView:(NCViewerTextModeView*)_view
    requestsSyncBackendWindowMovementAt:(int64_t)_position;

@end
