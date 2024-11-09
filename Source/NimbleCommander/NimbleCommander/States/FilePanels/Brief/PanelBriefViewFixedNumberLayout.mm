// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelBriefViewFixedNumberLayout.h"
#include "PanelBriefViewFixedNumberLayoutEngine.h"
#include <Panel/Log.h>
#include <algorithm>
#include <optional>

using nc::panel::Log;
using nc::panel::view::brief::FixedNumberLayoutEngine;

namespace {

struct ColumnAnchor {
    int column_index = 0;
    int offset_from_left_border = 0;
};

} // namespace

@implementation NCPanelBriefViewFixedNumberLayout {
    int m_ItemHeight;
    int m_ColumnsPerScreen;
    FixedNumberLayoutEngine m_Engine;
}

@synthesize layoutDelegate;
@synthesize itemHeight = m_ItemHeight;
@synthesize columnsPerScreen = m_ColumnsPerScreen;

- (instancetype)init
{
    self = [super init];
    if( self ) {
        m_ItemHeight = 20;
        m_ColumnsPerScreen = 3;
        self.scrollDirection = NSCollectionViewScrollDirectionHorizontal;
    }
    return self;
}

- (NSSize)collectionViewContentSize
{
    const auto sz = m_Engine.ContentSize();
    Log::Trace("[NCPanelBriefViewFixedNumberLayout collectionViewContentSize], return: {}", sz);
    return sz;
}

- (NSCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)_index_path
{
    const auto index = static_cast<int>(_index_path.item);
    Log::Trace("[NCPanelBriefViewFixedNumberLayout layoutAttributesForItemAtIndexPath={}]", index);
    return m_Engine.AttributesForItemNumber(index);
}

- (NSArray *)layoutAttributesForElementsInRect:(NSRect)_rect
{
    Log::Trace("[NCPanelBriefViewFixedNumberLayout layoutAttributesForElementsInRect:{}]", _rect);
    return m_Engine.AttributesForItemsInRect(_rect);
}

- (nullable NSCollectionViewLayoutAttributes *)
    layoutAttributesForSupplementaryViewOfKind:(NSCollectionViewSupplementaryElementKind) [[maybe_unused]] _elementKind
                                   atIndexPath:(NSIndexPath *) [[maybe_unused]] _indexPath
{
    return nil;
}

- (nullable NSCollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:
                                                   (NSCollectionViewDecorationElementKind) [[maybe_unused]] _elementKind
                                                                           atIndexPath:(NSIndexPath *)
                                                                                           [[maybe_unused]] _indexPath
{
    return nil;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(NSRect)_new_bounds
{
    const auto result = m_Engine.ShouldRelayoutForNewBounds(_new_bounds);
    Log::Trace("[NCPanelBriefViewFixedNumberLayout shouldInvalidateLayoutForBoundsChange:{}], return: {}",
               _new_bounds,
               result);
    return result;
}

- (void)prepareLayout
{
    Log::Trace("[NCPanelBriefViewFixedNumberLayout prepareLayout]");
    const auto anchor = [self getColumnAnchor];
    const auto collection_view = self.collectionView;
    const auto clip_bounds = collection_view.superview.bounds;
    const auto items_number = static_cast<int>([collection_view.dataSource collectionView:collection_view
                                                                   numberOfItemsInSection:0]);

    FixedNumberLayoutEngine::Params params;
    params.items_number = items_number;
    params.item_height = m_ItemHeight;
    params.columns_per_screen = m_ColumnsPerScreen;
    params.clip_view_bounds = clip_bounds;

    m_Engine.Layout(params);

    if( anchor )
        [self restoreColumnAnchor:*anchor];

    [self notifyDelegateAboutDoneLayout];
}

- (void)notifyDelegateAboutDoneLayout
{
    if( [self.layoutDelegate respondsToSelector:@selector(collectionViewDidLayoutItems:)] )
        [self.layoutDelegate collectionViewDidLayoutItems:self.collectionView];
}

- (int)columnsNumber
{
    return m_Engine.ColumnsNumber();
}

- (const std::vector<int> &)columnsPositions
{
    return m_Engine.ColumnsPositions();
}

- (const std::vector<int> &)columnsWidths
{
    return m_Engine.ColumnsWidths();
}

- (int)rowsNumber
{
    return m_Engine.RowsNumber();
}

- (void)setItemHeight:(int)_item_height
{
    if( m_ItemHeight == _item_height )
        return;
    if( _item_height < 1 )
        return;
    m_ItemHeight = _item_height;
    [self invalidateLayout];
}

- (void)setColumnsPerScreen:(int)_columns_per_screen
{
    if( m_ColumnsPerScreen == _columns_per_screen )
        return;
    if( _columns_per_screen < 1 )
        return;
    m_ColumnsPerScreen = _columns_per_screen;
    [self invalidateLayout];
}

- (std::optional<ColumnAnchor>)getColumnAnchor
{
    const auto &col_positions = m_Engine.ColumnsPositions();
    if( col_positions.empty() )
        return std::nullopt;

    const auto scroll_view = self.collectionView.enclosingScrollView;
    const auto visible_rect = scroll_view.documentVisibleRect;
    const auto left_border = static_cast<int>(visible_rect.origin.x);
    const auto col_it = std::ranges::lower_bound(col_positions, left_border);
    if( col_it == col_positions.end() )
        return std::nullopt;

    ColumnAnchor anchor;
    anchor.column_index = static_cast<int>(std::distance(col_positions.begin(), col_it));
    anchor.offset_from_left_border = *col_it - left_border;
    return anchor;
}

- (void)restoreColumnAnchor:(const ColumnAnchor &)_anchor
{
    const auto scroll_view = self.collectionView.enclosingScrollView;
    const auto visible_rect = scroll_view.documentVisibleRect;
    const auto left_border = static_cast<int>(visible_rect.origin.x);

    const auto &col_positions = m_Engine.ColumnsPositions();
    if( _anchor.column_index >= static_cast<int>(col_positions.size()) )
        return;

    const auto current_offset = col_positions[_anchor.column_index] - left_border;
    const auto offset_delta = _anchor.offset_from_left_border - current_offset;
    if( offset_delta != 0 ) {
        const auto old_pos = scroll_view.contentView.bounds.origin;
        const auto new_pos = NSMakePoint(old_pos.x - offset_delta, old_pos.y);
        const auto clip_view = scroll_view.contentView;
        [clip_view scrollToPoint:new_pos];
    }
}

@end
