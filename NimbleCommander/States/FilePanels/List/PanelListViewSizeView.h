#pragma once

@interface PanelListViewSizeView : NSView

- (void) buildPresentation;

// PanelListViewSizeView has no right to store listing item and hold a reference to it!
- (void) setSizeWithItem:(const VFSListingItem &)_dirent
                   andVD:(const PanelDataItemVolatileData &)_vd;

@end
