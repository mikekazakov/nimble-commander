// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelBriefViewLayoutEngineBase.h"
#include <cmath>

namespace nc::panel::view::brief {

int LayoutEngineBase::NumberOfRowsForViewHeight(double _view_height, int _item_height) noexcept
{
    if( _item_height > 0  && _view_height >= 0.0 )
        return (int)std::floor(_view_height / _item_height);
    else
        return 0;
}    

template <typename It>
static It FindFirstColumnPosForRect(It _first, It _last,  NSRect _rect) noexcept
{
    auto pos = std::lower_bound(_first, _last, int(_rect.origin.x));
    if( pos == _last )
        return pos;
    
    if( *pos > (int)_rect.origin.x && pos != _first )
        pos = std::prev(pos);
    
    return pos;
}
    
template <typename It>
static It FindLastColumnPosForRect(It _first, It _last,  NSRect _rect) noexcept
{
    return std::lower_bound(_first, _last, int(_rect.origin.x + _rect.size.width));
}
    
NSArray<NSCollectionViewLayoutAttributes*> *
    LayoutEngineBase::LogarithmicSearchForItemsInRect(NSRect _rect) const noexcept
{
    // 2 * O( ln2(N) ); 
    const auto first_col = FindFirstColumnPosForRect(m_ColumnsPositions.begin(),
                                                     m_ColumnsPositions.end(),
                                                     _rect);
    if( first_col == m_ColumnsPositions.end() )
        return [[NSArray alloc] init];    
    const auto last_col = FindLastColumnPosForRect(m_ColumnsPositions.begin(),
                                                   m_ColumnsPositions.end(),
                                                   _rect);
    
    const auto first_row_index = (int)std::floor(_rect.origin.y / m_ItemHeight);
    const auto last_row_index = std::min((int)std::ceil( (_rect.origin.y + _rect.size.height) / m_ItemHeight),
                                    m_RowsNumber);
    const auto first_col_index = (int)std::distance(m_ColumnsPositions.begin(), first_col);
    const auto last_col_index = (int)std::distance(m_ColumnsPositions.begin(), last_col);
    
    NSMutableArray *array = [[NSMutableArray alloc] init];    
    for( int column = first_col_index; column < last_col_index; ++column ) {
        for( int row = first_row_index; row < last_row_index; ++row ) {
            const auto index = column * m_RowsNumber + row;
            if( index >= 0 && index < m_ItemsNumber ) {
                [array addObject:m_Attributes[index]];
            }
        }
    }
    return array;
}

    
}
