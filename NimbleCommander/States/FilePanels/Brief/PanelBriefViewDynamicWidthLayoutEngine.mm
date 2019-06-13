// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelBriefViewDynamicWidthLayoutEngine.h"

namespace nc::panel::view::brief {

void DynamicWidthLayoutEngine::Layout( const Params &_params )
{
    CopyInputData(_params);
    m_RowsNumber = NumberOfRowsForViewHeight(_params.clip_view_bounds.size.height, m_ItemHeight); 
    if( m_RowsNumber == 0 ) {
        m_ColumnsNumber = m_ItemsNumber > 0 ? 1 : 0;
        PerformSingularLayout();
    }
    else {
        m_ColumnsNumber = (m_ItemsNumber % m_RowsNumber != 0) ? 
            (m_ItemsNumber / m_RowsNumber + 1) :
            (m_ItemsNumber / m_RowsNumber);
        PerformNormalLayout(_params);
    }
}
    
void DynamicWidthLayoutEngine::CopyInputData( const Params &_params )
{
    if(_params.items_number < 0 ||
       _params.item_height < 1 ||
       _params.item_min_width < 1 ||
       _params.item_max_width < 1 ||
       _params.item_min_width > _params.item_max_width || 
       _params.items_intrinsic_widths == nullptr ||
       (int)_params.items_intrinsic_widths->size() != _params.items_number )
        throw std::logic_error("DynamicWidthLayoutEngine: invalid input data");
    m_ItemsNumber = _params.items_number;
    m_ItemHeight = _params.item_height;
    m_ItemMinWidth = _params.item_min_width;
    m_ItemMaxWidth = _params.item_max_width;
}

void DynamicWidthLayoutEngine::PerformNormalLayout( const Params &_params )
{
    assert( m_RowsNumber != 0 );

    m_ColumnsPositions.resize(m_ColumnsNumber);
    m_ColumnsWidths.resize(m_ColumnsNumber);
    m_Attributes.resize(m_ItemsNumber);
    
    const auto items_number = m_ItemsNumber;
    const auto item_height = m_ItemHeight;
    const auto columns_number = m_ColumnsNumber;
    const auto rows_number = m_RowsNumber;
    const auto &items_intrinsic_widths = *_params.items_intrinsic_widths;
    auto current_column_position = 0;
    
    for( int column_index = 0; column_index < columns_number; ++column_index ) {
        const auto first_index = column_index * rows_number;
        const auto last_index = std::min( (column_index + 1) * rows_number, items_number );
        const auto max_width = *std::max_element(items_intrinsic_widths.begin() + first_index, 
                                                 items_intrinsic_widths.begin() + last_index);
        const auto column_width = std::clamp((int)max_width, m_ItemMinWidth, m_ItemMaxWidth);
        
        for( int index = first_index, row_number = first_index % rows_number;
            index < last_index;
            ++index, ++row_number ) {
            const auto origin = NSMakePoint(current_column_position, row_number * item_height);            
            const auto index_path = [NSIndexPath indexPathForItem:index inSection:0];
            const auto attributes =
                [NSCollectionViewLayoutAttributes layoutAttributesForItemWithIndexPath:index_path];
            attributes.frame = NSMakeRect(origin.x, origin.y, column_width, item_height);
            m_Attributes[index] = attributes;
        }

        m_ColumnsPositions[column_index] = current_column_position;
        m_ColumnsWidths[column_index] = column_width;
        current_column_position += column_width;
    }
    
    m_ContentSize = NSMakeSize(current_column_position, m_RowsNumber * m_ItemHeight);
}

void DynamicWidthLayoutEngine::PerformSingularLayout()
{
    assert( m_RowsNumber == 0 );

    m_ColumnsPositions.resize(m_ColumnsNumber);
    m_ColumnsWidths.resize(m_ColumnsNumber);
    m_Attributes.resize(m_ItemsNumber);
    
    const auto items_number = m_ItemsNumber;
    const auto frame = NSMakeRect(0.0, 0.0, m_ItemMinWidth, m_ItemHeight);
    
    for( int index = 0; index < items_number; ++index ) {
        const auto index_path = [NSIndexPath indexPathForItem:index inSection:0];
        const auto attributes =
            [NSCollectionViewLayoutAttributes layoutAttributesForItemWithIndexPath:index_path];
        attributes.frame = frame;
        m_Attributes[index] = attributes;
    }
    
    std::fill( m_ColumnsPositions.begin(), m_ColumnsPositions.end(), 0 );
    std::fill( m_ColumnsWidths.begin(), m_ColumnsWidths.end(), m_ItemMinWidth );    
    m_ContentSize = NSMakeSize(m_ColumnsNumber * m_ItemMinWidth, m_ItemHeight);
}

bool DynamicWidthLayoutEngine::
    ShouldRelayoutForNewBounds(const NSRect clip_view_bounds) const noexcept
{
    const auto height = clip_view_bounds.size.height;
    const auto projected_rows_number = NumberOfRowsForViewHeight(height, m_ItemHeight);
    if( projected_rows_number != m_RowsNumber )
        return true;
    else
        return false;        
}

NSArray<NSCollectionViewLayoutAttributes*> *
    DynamicWidthLayoutEngine::AttributesForItemsInRect(NSRect _rect) const noexcept
{
    return LogarithmicSearchForItemsInRect(_rect);
}

}
