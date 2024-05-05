// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

#include <Panel/PanelDataItemVolatileData.h>
#include <Panel/PanelDataStatistics.h>
#include "PanelViewFooterTheme.h"

@interface NCPanelViewFooter : NSView

- (id)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;

- (id)initWithFrame:(NSRect)frameRect theme:(std::unique_ptr<nc::panel::FooterTheme>)_theme;

- (void)updateFocusedItem:(const VFSListingItem &)_item VD:(nc::panel::data::ItemVolatileData)_vd; // may be empty
- (void)updateStatistics:(const nc::panel::data::Statistics &)_stats;
- (void)updateListing:(const VFSListingPtr &)_listing;

@property(nonatomic) bool active;

@end
