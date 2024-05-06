// Copyright (C) 2016-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <Panel/PanelDataItemVolatileData.h>

@class PanelBriefView;
@class NCPanelViewFieldEditor;

@interface PanelBriefViewItem : NSCollectionViewItem

/**
 * returns -1 on failure.
 */
- (int)itemIndex;

/**
 * returns -1 on failure.
 */
- (int)columnIndex;

- (VFSListingItem)item;
- (void)setItem:(VFSListingItem)_item;
- (void)setVD:(nc::panel::data::ItemVolatileData)_vd;
- (void)setIcon:(NSImage *)_icon;
@property(nonatomic) bool panelActive;

- (PanelBriefView *)briefView;

- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor;

- (void)updateItemLayout;

@end
