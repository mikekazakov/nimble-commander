// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelBriefViewFixedWidthLayoutEngine.h"
#include <cmath>

namespace nc::panel::view::brief {

void FixedWidthLayoutEngine::Layout( const FixedWidthLayoutEngine::Params &_params )
{
    CopyInputData(_params);
    BuildGrid(_params);
    BuildItemsLayout();
}
    
void FixedWidthLayoutEngine::CopyInputData(const Params &_params)
{
    if( _params.items_number < 0 ||
        _params.item_height < 1 ||
        _params.item_width < 1 )
        throw std::logic_error("FixedWidthLayoutEngine: invalid input data");
    m_ItemsNumber = _params.items_number;        
    m_ItemWidth = _params.item_width;
    m_ItemHeight = _params.item_height;
}
    
static void FillColumnsPositions( std::vector<int> &_pos, int _number, int _item_width )
{
    auto generator = [pos = 0, step = _item_width] () mutable {
        auto ret = pos;
        pos += step;
        return ret;
    };
    _pos.resize(_number);    
    std::generate(_pos.begin(), _pos.end(), generator);
}

static void FillColumnsWidths( std::vector<int> &_widths, int _number, int _item_width )
{
    _widths.resize(_number);
    std::fill(_widths.begin(), _widths.end(), _item_width);
}

void FixedWidthLayoutEngine::BuildGrid(const Params &_params)
{
    m_RowsNumber = NumberOfRowsForViewHeight(_params.clip_view_bounds.size.height, m_ItemHeight);
    if( m_RowsNumber == 0 ) {
        m_ColumnsNumber = 0;
        m_ContentSize = NSMakeSize(0.0, 0.0);
        m_ColumnsPositions.resize(0);
        m_ColumnsWidths.resize(0);
    }
    else {
        m_ColumnsNumber = (m_ItemsNumber % m_RowsNumber != 0) ? 
            (m_ItemsNumber / m_RowsNumber + 1) :
            (m_ItemsNumber / m_RowsNumber);
        m_ContentSize = NSMakeSize(m_ColumnsNumber * m_ItemWidth, m_RowsNumber * m_ItemHeight);
        FillColumnsPositions(m_ColumnsPositions, m_ColumnsNumber, m_ItemWidth);
        FillColumnsWidths(m_ColumnsWidths, m_ColumnsNumber, m_ItemWidth); 
    }
}

void FixedWidthLayoutEngine::BuildItemsLayout()
{
    const auto items_number = m_ItemsNumber;
    const auto item_size = NSMakeSize(m_ItemWidth, m_ItemHeight);
    m_Attributes.resize(items_number);
    if( m_RowsNumber != 0 ) {
        for( int index = 0; index < items_number; ++index ) {
            const auto column_number = index / m_RowsNumber;
            const auto row_number = index % m_RowsNumber;
            const auto origin = NSMakePoint(column_number * m_ItemWidth, row_number * m_ItemHeight);
            const auto index_path = [NSIndexPath indexPathForItem:index inSection:0];
            const auto attributes =
                [NSCollectionViewLayoutAttributes layoutAttributesForItemWithIndexPath:index_path];
            attributes.frame = NSMakeRect(origin.x, origin.y, item_size.width, item_size.height);
            m_Attributes[index] = attributes;
        }
    }
    else {
        // for an invalid state (view height is less than one item) we just shove all entires 
        // at the same position.
        const auto frame = NSMakeRect(0.0, 0.0, item_size.width, item_size.height);
        for( int index = 0; index < items_number; ++index ) {
            const auto index_path = [NSIndexPath indexPathForItem:index inSection:0];
            const auto attributes =
                [NSCollectionViewLayoutAttributes layoutAttributesForItemWithIndexPath:index_path];
            attributes.frame = frame;
            m_Attributes[index] = attributes;
        }
    }   
}

bool FixedWidthLayoutEngine::
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
    FixedWidthLayoutEngine::AttributesForItemsInRect(NSRect _rect) const noexcept
{
    const auto first_column = (int)std::floor(_rect.origin.x / m_ItemWidth);
    const auto last_column = std::min((int)std::ceil((_rect.origin.x + _rect.size.width) / m_ItemWidth),
                                 m_ColumnsNumber);
    const auto first_row = (int)std::floor(_rect.origin.y / m_ItemHeight);
    const auto last_row = std::min((int)std::ceil( (_rect.origin.y + _rect.size.height) / m_ItemHeight ),
                              m_RowsNumber);
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for( int column = first_column; column < last_column; ++column )
        for( int row = first_row; row < last_row; ++row ) {
            const auto index = column * m_RowsNumber + row;
            if( index >= 0 && index < m_ItemsNumber ) {
                [array addObject:m_Attributes[index]];
            }
        }
    return array;        
}

}
