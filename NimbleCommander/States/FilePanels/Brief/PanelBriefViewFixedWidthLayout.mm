// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelBriefViewFixedWidthLayout.h"
#include "PanelBriefViewFixedWidthLayoutEngine.h"

using nc::panel::view::brief::FixedWidthLayoutEngine;

@implementation NCPanelBriefViewFixedWidthLayout
{
    int m_ItemWidth;
    int m_ItemHeight;
    FixedWidthLayoutEngine m_Engine;
}

@synthesize itemWidth = m_ItemWidth;
@synthesize itemHeight = m_ItemHeight;
@synthesize layoutDelegate;

- (instancetype) init
{
    if( self = [super init] ) {
        m_ItemWidth = 150;
        m_ItemHeight = 20;
        self.scrollDirection = NSCollectionViewScrollDirectionHorizontal;
    }
    return self;
}

- (NSSize)collectionViewContentSize
{
    return m_Engine.ContentSize();
}

- (NSCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)_index_path
{
    const auto index = (int)_index_path.item;
    return m_Engine.AttributesForItemNumber(index);
}

- (NSArray *)layoutAttributesForElementsInRect:(NSRect)_rect
{
    return m_Engine.AttributesForItemsInRect(_rect);
}

- (nullable NSCollectionViewLayoutAttributes*)
    layoutAttributesForSupplementaryViewOfKind:(NSCollectionViewSupplementaryElementKind)
                                                   [[maybe_unused]] _element_kind
                                   atIndexPath:(NSIndexPath*)[[maybe_unused]] _index_path
{
    return nil;
}

- (nullable NSCollectionViewLayoutAttributes*)
    layoutAttributesForDecorationViewOfKind:(NSCollectionViewDecorationElementKind)
                                                [[maybe_unused]] _element_kind
                                atIndexPath:(NSIndexPath*)[[maybe_unused]] _index_path
{
    return nil;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(NSRect)_new_bounds
{
    return m_Engine.ShouldRelayoutForNewBounds(_new_bounds);
}

- (void)prepareLayout
{
    const auto collection_view = self.collectionView;
    const auto clip_bounds = collection_view.superview.bounds;    
    const auto items_number = (int)[collection_view.dataSource collectionView:collection_view
                                                       numberOfItemsInSection:0];
    
    FixedWidthLayoutEngine::Params params;
    params.item_width = m_ItemWidth;
    params.item_height = m_ItemHeight;
    params.items_number = items_number;
    params.clip_view_bounds = clip_bounds;
    m_Engine.Layout(params);

    [self notifyDelegateAboutDoneLayout];
}

- (void) notifyDelegateAboutDoneLayout
{
    if( [self.layoutDelegate respondsToSelector:@selector(collectionViewDidLayoutItems:)] )
        [self.layoutDelegate collectionViewDidLayoutItems:self.collectionView];    
}

- (int) rowsNumber
{
    return m_Engine.RowsNumber();
}

- (int) columnsNumber
{
    return m_Engine.ColumnsNumber();
}

- (const std::vector<int>&) columnsPositions
{
    return m_Engine.ColumnsPositions();
}

- (const std::vector<int>&) columnsWidths
{
    return m_Engine.ColumnsWidths();
}

- (void) setItemWidth:(int)_item_width
{
    if( m_ItemWidth == _item_width )
        return;
    if( _item_width < 1 )
        return;
    m_ItemWidth = _item_width;
    [self invalidateLayout];
}

- (void) setItemHeight:(int)_item_height
{
    if( m_ItemHeight == _item_height )
        return;
    if( _item_height < 1 )
        return;
    m_ItemHeight = _item_height;
    [self invalidateLayout];
}

@end
