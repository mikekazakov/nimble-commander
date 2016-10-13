#pragma once

class PanelData;
struct PanelViewPresentationItemsColoringRule;
@class PanelView;

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

// 3 modes:
// - fixed widths for columns
//      setting: this width
// - fixed amount of columns
//      setting: amount of columns
// - dynamic widths of columns
//      settings: min width, max width, should be equal

@interface PanelBriefView : NSView<NSCollectionViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout>

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(PanelData*)_data;

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;


- (vector<PanelViewPresentationItemsColoringRule>&) coloringRules;

- (PanelBriefViewItemLayoutConstants) layoutConstants;

@end
