// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelBriefViewDynamicWidthLayout.h"
#include "PanelBriefViewDynamicWidthLayoutEngine.h"
#include <mutex>

using nc::panel::view::brief::DynamicWidthLayoutEngine;

@implementation NCPanelBriefViewDynamicWidthLayout
{
    int m_ItemHeight;
    int m_ItemMinWidth;
    int m_ItemMaxWidth;
    DynamicWidthLayoutEngine m_Engine;
}

@synthesize layoutDelegate;
@synthesize itemHeight = m_ItemHeight;
@synthesize itemMinWidth = m_ItemMinWidth;
@synthesize itemMaxWidth = m_ItemMaxWidth; 

- (instancetype) init
{
    if( self = [super init] ) {
        m_ItemHeight = 20;
        m_ItemMinWidth = 140;
        m_ItemMaxWidth = 400;        
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
                                                   [[maybe_unused]] _elementKind
                                   atIndexPath:(NSIndexPath*)[[maybe_unused]] _indexPath
{
    return nil;
}

- (nullable NSCollectionViewLayoutAttributes*)
    layoutAttributesForDecorationViewOfKind:(NSCollectionViewDecorationElementKind)
                                                [[maybe_unused]] _elementKind
                                atIndexPath:(NSIndexPath*)[[maybe_unused]] _indexPath
{
    return nil;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(NSRect)_new_bounds
{
    return m_Engine.ShouldRelayoutForNewBounds(_new_bounds);
}

- (bool)delegateProvidesIntrinsicWidths
{
    const auto delegate = self.layoutDelegate;
    const auto selector = @selector(collectionViewProvideIntrinsicItemsWidths:);
    if( [delegate respondsToSelector:selector] == false) {
        static std::once_flag once;
        std::call_once(once, []{
            NSLog(@"A delegate doesn't provide collectionViewProvideIntrinsicItemsWidths:, "
                  "NCPanelBriefViewDynamicWidthLayout can not work without it.");
        });
        return false;
    }
    return true;
}

- (void)prepareLayout
{
    if( [self delegateProvidesIntrinsicWidths] == false )
        return;
    
    const auto collection_view = self.collectionView;
    const auto clip_bounds = collection_view.superview.bounds;    
    const auto items_number = (int)[collection_view.dataSource collectionView:collection_view
                                                       numberOfItemsInSection:0];
    const auto delegate = self.layoutDelegate;
    const auto &widths = [delegate collectionViewProvideIntrinsicItemsWidths:collection_view];
    
    DynamicWidthLayoutEngine::Params params;
    params.items_number = items_number;
    params.item_height = m_ItemHeight;
    params.item_min_width = m_ItemMinWidth;
    params.item_max_width = m_ItemMaxWidth;    
    params.clip_view_bounds = clip_bounds;
    params.items_intrinsic_widths = &widths;
    
    m_Engine.Layout(params);
    
    [self notifyDelegateAboutDoneLayout];
}

- (void) notifyDelegateAboutDoneLayout
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

- (void)setItemMinWidth:(int)_item_min_width
{
    if( m_ItemMinWidth == _item_min_width )
        return;
    if( _item_min_width < 1 )
        return;
    m_ItemMinWidth = _item_min_width;
    [self invalidateLayout];
}

- (void)setItemMaxWidth:(int)_item_max_width
{
    if( m_ItemMaxWidth == _item_max_width )
        return;
    if( _item_max_width < 1 )
        return;
    m_ItemMaxWidth = _item_max_width;
    [self invalidateLayout];
}

@end
