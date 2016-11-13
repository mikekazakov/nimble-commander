#include "Layout.h"

static_assert( sizeof(PanelListViewColumnsLayout::Column) == 8 );

bool PanelListViewColumnsLayout::Column::operator==( const Column& _rhs ) const noexcept
{
    return kind == _rhs.kind &&
            width == _rhs.width &&
            max_width == _rhs.max_width &&
            min_width == _rhs.min_width;
}

bool PanelListViewColumnsLayout::Column::operator!=( const Column& _rhs ) const noexcept
{
    return !(*this == _rhs);
}

bool PanelListViewColumnsLayout::operator==( const PanelListViewColumnsLayout& _rhs ) const noexcept
{
    return columns == _rhs.columns;
}

bool PanelListViewColumnsLayout::operator!=( const PanelListViewColumnsLayout& _rhs ) const noexcept
{
    return !(*this == _rhs);
}
