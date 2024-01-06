// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFSIcon/IconRepository.h>
#include "../PanelViewImplementationProtocol.h"
#include "Layout.h"
#include "PanelBriefViewLayoutProtocol.h"

@class PanelView;

namespace nc::panel {
namespace data {
    class Model;
    struct SortMode;
}
}

/**
 *  [inset_left|icon|inset_left|...text...|inset_right] 
 */
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

@interface PanelBriefView : NSView<NCPanelViewPresentationProtocol,
                                   NCPanelBriefViewLayoutDelegate,
                                   NSCollectionViewDelegate,
                                   NSCollectionViewDataSource>

- (id)initWithFrame:(NSRect)frameRect andIR:(nc::vfsicon::IconRepository&)_ir;

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(nc::panel::data::Model*)_data;

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;
@property (nonatomic) nc::panel::data::SortMode sortMode;

@property (nonatomic) PanelBriefViewColumnsLayout columnsLayout;


- (PanelBriefViewItemLayoutConstants) layoutConstants;

- (PanelView*) panelView;

@end
