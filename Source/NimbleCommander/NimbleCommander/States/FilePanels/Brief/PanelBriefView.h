// Copyright (C) 2016-2025 Michael Kazakov. Subject to GNU General Public License version 3.
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
} // namespace data
} // namespace nc::panel

/**
 *  [inset_left|icon|inset_left|...text...|inset_right]
 */
struct PanelBriefViewItemLayoutConstants {
    int8_t inset_left;
    int8_t inset_top;
    int8_t inset_right;
    int8_t inset_bottom;
    int16_t icon_size;
    int16_t font_baseline;
    int16_t item_height;
    constexpr bool operator==(const PanelBriefViewItemLayoutConstants &_rhs) const noexcept = default;
};

@interface NCPanelBriefView : NSView <NCPanelViewPresentationProtocol,
                                      NCPanelBriefViewLayoutDelegate,
                                      NSCollectionViewDelegate,
                                      NSCollectionViewDataSource>

- (id)initWithFrame:(NSRect)frameRect iconRepository:(nc::vfsicon::IconRepository &)_ir;

- (void)onDataChanged;
- (void)onVolatileDataChanged;
- (void)setData:(nc::panel::data::Model *)_data;

@property(nonatomic, readonly) int itemsInColumn;
@property(nonatomic) int cursorPosition;

@property(nonatomic) nc::panel::PanelBriefViewColumnsLayout columnsLayout;

- (PanelBriefViewItemLayoutConstants)layoutConstants;

- (PanelView *)panelView;

@end
