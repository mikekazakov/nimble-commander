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

struct PanelBriefViewColumnsLayout
{
    enum class Mode : short {
        FixedWidth      = 0,
        FixedAmount     = 1,
        DynamicWidth    = 2
    };
    Mode    mode                = Mode::FixedAmount;
    short   fixed_mode_width    = 150;
    short   fixed_amount_value  = 3;
    short   dynamic_width_min   = 100;
    short   dynamic_width_max   = 300;
    bool    dynamic_width_equal = false;
    bool operator ==(const PanelBriefViewColumnsLayout& _rhs) const noexcept;
    bool operator !=(const PanelBriefViewColumnsLayout& _rhs) const noexcept;
};

@interface PanelBriefView : NSView<NSCollectionViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout>

- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(PanelData*)_data;

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;
@property (nonatomic) NSFont *font;

@property (nonatomic) NSColor *regularBackgroundColor;
@property (nonatomic) NSColor *alternateBackgroundColor;

@property (nonatomic) PanelBriefViewColumnsLayout columnsLayout;

- (vector<PanelViewPresentationItemsColoringRule>&) coloringRules;

- (PanelBriefViewItemLayoutConstants) layoutConstants;

- (PanelView*) panelView;

@end
