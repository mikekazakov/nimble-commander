// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Layout.h"

static_assert( sizeof(PanelListViewColumnsLayout::Column) == 8 );

PanelListViewColumnsLayout::Column::Column() noexcept:
    kind(PanelListViewColumns::Empty),
    width(-1),
    max_width(-1),
    min_width(-1)
{
}

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

PanelListViewColumnsLayout::PanelListViewColumnsLayout() noexcept:
    icon_scale(1)
{
}

bool PanelListViewColumnsLayout::operator==( const PanelListViewColumnsLayout& _rhs ) const noexcept
{
    return columns == _rhs.columns &&
        icon_scale == _rhs.icon_scale;
}

bool PanelListViewColumnsLayout::operator!=( const PanelListViewColumnsLayout& _rhs ) const noexcept
{
    return !(*this == _rhs);
}
