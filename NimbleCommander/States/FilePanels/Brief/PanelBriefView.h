#pragma once

#include "../PanelDataSortMode.h"
#include "../PanelViewImplementationProtocol.h"

#include "Layout.h"

class PanelData;
struct PanelViewPresentationItemsColoringRule;
@class PanelView;
class IconsGenerator2;

struct PanelBriefViewItemLayoutConstants
{
    int8_t  inset_left;
    int8_t  inset_top;
    int8_t  inset_right;
    int8_t  inset_bottom;
    int16_t icon_size;
    int16_t font_baseline;
    int16_t item_height;
};

@interface PanelBriefView : NSView<PanelViewImplementationProtocol, NSCollectionViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout>

- (id)initWithFrame:(NSRect)frameRect andIC:(IconsGenerator2&)_ic;

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(PanelData*)_data;

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;
@property (nonatomic) PanelDataSortMode sortMode;

@property (nonatomic) PanelBriefViewColumnsLayout columnsLayout;


- (PanelBriefViewItemLayoutConstants) layoutConstants;

- (PanelView*) panelView;

@end
