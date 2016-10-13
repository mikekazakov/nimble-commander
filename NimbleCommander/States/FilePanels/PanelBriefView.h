#pragma once

class PanelData;
struct PanelViewPresentationItemsColoringRule;
@class PanelView;
//@class PanelBriefViewItem;


//static const double g_TextInsetsInLine[4] = {7, 1, 5, 1};

struct PanelBriefViewItemLayoutConstants
{
    int8_t  inset_left;
    int8_t  inset_top;
    int8_t  inset_right;
    int8_t  inset_bottom;
    int16_t icon_size;
    int16_t font_baseline;
};

@interface PanelBriefView : NSView<NSCollectionViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout>

//- (id)initWithFrame:(NSRect)frameRect andData:(PanelData&)_data;


- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(PanelData*)_data;

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;


- (vector<PanelViewPresentationItemsColoringRule>&) coloringRules;

- (PanelBriefViewItemLayoutConstants) layoutConstants;

@end
