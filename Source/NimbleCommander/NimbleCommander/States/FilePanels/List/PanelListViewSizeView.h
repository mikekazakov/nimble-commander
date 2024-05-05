// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <Panel/PanelDataItemVolatileData.h>

@interface PanelListViewSizeView : NSView

- (void)buildPresentation;

// PanelListViewSizeView has no right to store listing item and hold a reference to it!
- (void)setSizeWithItem:(const VFSListingItem &)_dirent andVD:(const nc::panel::data::ItemVolatileData &)_vd;

@end
