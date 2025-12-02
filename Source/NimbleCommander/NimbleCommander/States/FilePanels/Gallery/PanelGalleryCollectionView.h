// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface NCPanelGalleryViewCollectionView : NSCollectionView

// Should scrolling to an item be immediate or smoothly animated.
@property(nonatomic) bool smoothScrolling;

// Ensures that the item is present on the screen.
// Scrolls to the specified item if needed.
// smoothScrolling controls whether the scrolling will be immediate or animated.
- (void)ensureItemIsVisible:(int)_item_index;

@end
