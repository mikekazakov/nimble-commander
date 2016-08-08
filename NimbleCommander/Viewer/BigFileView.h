//
//  TextView.h
//  ViewerBase
//
//  Created by Michael G. Kazakov on 05.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Utility/Encodings.h>
#include "../../Files/FileWindow.h"
#include "../../Files/OrthodoxMonospace.h"

enum class BigFileViewModes : int
{ // changing this values may cause stored history corruption
    Text = 0,
    Hex  = 1
};

@protocol BigFileViewDelegateProtocol <NSObject>
@optional
- (void) BigFileViewScrolled;       // signal any movements of scroll bar - regardless of reason
                                    // should be used for UI updates only
- (void) BigFileViewScrolledByUser; // signal that position was changed with request of user
@end

@interface BigFileView : NSView

- (void) SetFile:(FileWindow*) _file;
- (void) SetKnownFile:(FileWindow*) _file encoding:(int)_encoding mode:(BigFileViewModes)_mode;

- (void) RequestWindowMovementAt: (uint64_t) _pos;
- (void) UpdateVerticalScroll: (double) _pos prop:(double)prop;

// appearance section
- (CTFontRef)   TextFont;
- (CGColorRef)  TextForegroundColor;
- (DoubleColor) SelectionBkFillColor;
- (DoubleColor) BackgroundFillColor;
- (bool)        ShouldAntialias;
- (bool)        ShouldSmoothFonts;

/**
 * Specify if view should draw a border.
 */
@property (nonatomic) bool hasBorder;

/**
 * Interior size, excluding scroll bar and possibly border
 */
@property (nonatomic, readonly) NSSize contentBounds;


// Frontend section

/**
 * Setting how data backend should translate raw bytes into UniChars characters.
 * KVO-compatible.
 */
@property (nonatomic) int encoding;

/**
 * Set if text presentation should fit lines into a view width to disable horiziontal scrolling.
 * That is done by breaking sentences by words wrapping.
 * KVO-compatible.
 */
@property (nonatomic) bool wordWrap;

/**
 * Visual presentation mode. Currently supports two: Text and Hex.
 * KVO-compatible.
 */
@property (nonatomic) BigFileViewModes mode;

/**
 * Scroll position within whole file, now in a window
 * KVO-compatible.
 */
@property (nonatomic) uint64_t verticalPositionInBytes;

/**
 * Tried to verticalPositionInBytes.
 * KVO-compatible, read-only.
 */
@property (nonatomic, readonly) double verticalPositionPercentage;

/**
 * Selection in whole file, in raw bytes.
 * It may render to different variant within concrete file window position.
 * If set with improper range (larger than whole file), it will be implicitly trimmed
 */
@property (nonatomic) CFRange selectionInFile;

- (double)      VerticalScrollPosition; // in percentage: [0..1]
- (void)        ScrollToSelection;
- (CFRange)     SelectionWithinWindow;                      // bytes within a decoded window
- (CFRange)     SelectionWithinWindowUnichars;              // unichars within a decoded window

@property (nonatomic, weak) id<BigFileViewDelegateProtocol> delegate;
@end
