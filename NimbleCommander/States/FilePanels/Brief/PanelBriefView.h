// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../PanelViewImplementationProtocol.h"

#include "Layout.h"

struct PanelViewPresentationItemsColoringRule;
@class PanelView;

namespace nc::panel {
class IconsGenerator2;
namespace data {
    class Model;
    struct SortMode;
}
}

struct PanelBriefViewItemLayoutConstants
{
    int8_t  inset_left;
    int8_t  inset_top;
    int8_t  inset_right;
    int8_t  inset_bottom;
    int16_t icon_size;
    int16_t font_baseline;
    int16_t item_height;
    bool operator ==(const PanelBriefViewItemLayoutConstants &_rhs) const noexcept;
    bool operator !=(const PanelBriefViewItemLayoutConstants &_rhs) const noexcept;
};

@interface PanelBriefView : NSView<PanelViewImplementationProtocol, NSCollectionViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout>

- (id)initWithFrame:(NSRect)frameRect andIC:(nc::panel::IconsGenerator2&)_ic;

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(nc::panel::data::Model*)_data;

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic, readonly) int columns;
@property (nonatomic) int cursorPosition;
@property (nonatomic) nc::panel::data::SortMode sortMode;

@property (nonatomic) PanelBriefViewColumnsLayout columnsLayout;


- (PanelBriefViewItemLayoutConstants) layoutConstants;

- (PanelView*) panelView;

@end
