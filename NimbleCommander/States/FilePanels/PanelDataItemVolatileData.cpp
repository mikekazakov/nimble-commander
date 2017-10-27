// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataItemVolatileData.h"

namespace nc::panel::data {

static_assert( sizeof(ItemVolatileData) == 16 );

bool ItemVolatileData::is_selected() const noexcept
{
    return (flags & flag_selected) != 0;
};

bool ItemVolatileData::is_shown() const noexcept
{
    return (flags & flag_shown) != 0;
}

bool ItemVolatileData::is_highlighted() const noexcept
{
    return (flags & flag_highlight) != 0;
}

bool ItemVolatileData::is_size_calculated() const noexcept
{
    return size != invalid_size;
}

void ItemVolatileData::toggle_selected( bool _v ) noexcept
{
    flags = (flags & ~flag_selected) | (_v ? flag_selected : 0);
}

void ItemVolatileData::toggle_shown( bool _v ) noexcept
{
    flags = (flags & ~flag_shown) | (_v ? flag_shown : 0);
}

void ItemVolatileData::toggle_highlight( bool _v ) noexcept
{
    flags = (flags & ~flag_highlight) | (_v ? flag_highlight : 0);
}

bool ItemVolatileData::operator==(ItemVolatileData &_rhs) const noexcept
{
    return size  == _rhs.size  &&
        flags == _rhs.flags &&
        icon  == _rhs.icon  &&
        qs_highlight_begin == _rhs.qs_highlight_begin &&
        qs_highlight_end == _rhs.qs_highlight_end;
}

bool ItemVolatileData::operator!=(ItemVolatileData &_rhs) const noexcept
{
    return !(*this == _rhs);
}

}
