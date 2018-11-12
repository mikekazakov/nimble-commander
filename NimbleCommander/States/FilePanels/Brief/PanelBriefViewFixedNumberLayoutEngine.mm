// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelBriefViewFixedNumberLayoutEngine.h"

namespace nc::panel::view::brief {

void FixedNumberLayoutEngine::Layout( const Params &_params )
{
    CopyInput(_params);
    BuildGrid(_params);
    if( m_RowsNumber != 0 )
        PerformNormalLayout();
    else
        PerformSingularLayout();
}

void FixedNumberLayoutEngine::CopyInput( const Params &_params )
{
    if( _params.items_number < 0 ||
        _params.item_height < 1 ||
        _params.columns_per_screen < 1  )
        throw std::invalid_argument("FixedWidthLayoutEngine: invalid params");

    m_ItemsNumber = _params.items_number;        
    m_ItemHeight = _params.item_height;
    m_ColumnsPerScreen = _params.columns_per_screen;
    m_ClipViewWidth = (int)_params.clip_view_bounds.size.width;
}

void FixedNumberLayoutEngine::BuildGrid( const Params &_params )
{
    const auto screen_width = (int)_params.clip_view_bounds.size.width;    
    m_BaseColumnWidth = screen_width / m_ColumnsPerScreen; 
    m_ScreenRemainder = screen_width % m_ColumnsPerScreen;
    
    m_RowsNumber = NumberOfRowsForViewHeight(_params.clip_view_bounds.size.height, m_ItemHeight);    
    if( m_RowsNumber == 0 ) {
        m_ColumnsNumber = m_ItemsNumber > 0 ? 1 : 0;
    }
    else {
        m_ColumnsNumber = (m_ItemsNumber % m_RowsNumber != 0) ? 
            (m_ItemsNumber / m_RowsNumber + 1) :
            (m_ItemsNumber / m_RowsNumber);        
    }
}    

void FixedNumberLayoutEngine::PerformNormalLayout()
{   
    assert( m_RowsNumber != 0 );
    
    m_ColumnsPositions.resize(m_ColumnsNumber);
    m_ColumnsWidths.resize(m_ColumnsNumber);
    m_Attributes.resize(m_ItemsNumber);
    
    const auto items_number = m_ItemsNumber;
    const auto item_height = m_ItemHeight;
    const auto columns_number = m_ColumnsNumber;
    const auto columns_per_screen = m_ColumnsPerScreen;
    const auto rows_number = m_RowsNumber;
    const auto base_width = m_BaseColumnWidth;
    const auto screen_remainder = m_ScreenRemainder;
    
    auto current_column_position = 0;
    for( int column_index = 0; column_index < columns_number; ++column_index ) {
        const auto index_in_chunk = column_index % columns_per_screen;
        const auto column_width = base_width + (index_in_chunk < screen_remainder ? 1 : 0);
        
        for( int row_index = 0; row_index < rows_number; ++row_index ) {
            const auto index = column_index * rows_number + row_index;
            if( index == items_number )
                break;
            
            const auto origin = NSMakePoint(current_column_position, row_index * item_height);            
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
    m_ContentSize = NSMakeSize(current_column_position, rows_number * item_height);
}
    
void FixedNumberLayoutEngine::PerformSingularLayout()
{
    assert( m_RowsNumber == 0 );
    m_ColumnsPositions.resize(m_ColumnsNumber);
    m_ColumnsWidths.resize(m_ColumnsNumber);
    m_Attributes.resize(m_ItemsNumber);

    const auto items_number = m_ItemsNumber;
    const auto frame = NSMakeRect(0.0, 0.0, m_BaseColumnWidth, m_ItemHeight);
    
    for( int index = 0; index < items_number; ++index ) {
        const auto index_path = [NSIndexPath indexPathForItem:index inSection:0];
        const auto attributes =
        [NSCollectionViewLayoutAttributes layoutAttributesForItemWithIndexPath:index_path];
            attributes.frame = frame;
        m_Attributes[index] = attributes;
    }
    
    std::fill( m_ColumnsPositions.begin(), m_ColumnsPositions.end(), 0 );
    std::fill( m_ColumnsWidths.begin(), m_ColumnsWidths.end(), m_BaseColumnWidth );
    m_ContentSize = NSMakeSize(m_ColumnsNumber * m_BaseColumnWidth, m_ItemHeight);    
}        
    
bool FixedNumberLayoutEngine::
    ShouldRelayoutForNewBounds(const NSRect clip_view_bounds) const noexcept
{ 
    if( (int)clip_view_bounds.size.width != m_ClipViewWidth )
        return true;
    
    const auto height = clip_view_bounds.size.height;
    const auto projected_rows_number = NumberOfRowsForViewHeight(height, m_ItemHeight);
    if( projected_rows_number != m_RowsNumber )
        return true;
    else
        return false;    
}
    
NSArray<NSCollectionViewLayoutAttributes*> *
    FixedNumberLayoutEngine::AttributesForItemsInRect(NSRect _rect) const noexcept
{
    return LogarithmicSearchForItemsInRect(_rect);
}

}
