#include "PanelDataItemVolatileData.h"

static_assert( sizeof(PanelDataItemVolatileData) == 16 );

bool PanelDataItemVolatileData::is_selected() const noexcept
{
    return (flags & flag_selected) != 0;
};

bool PanelDataItemVolatileData::is_shown() const noexcept
{
    return (flags & flag_shown) != 0;
}

bool PanelDataItemVolatileData::is_highlighted() const noexcept
{
    return (flags & flag_highlight) != 0;
}

bool PanelDataItemVolatileData::is_size_calculated() const noexcept
{
    return size != invalid_size;
}

void PanelDataItemVolatileData::toggle_selected( bool _v ) noexcept
{
    flags = (flags & ~flag_selected) | (_v ? flag_selected : 0);
}

void PanelDataItemVolatileData::toggle_shown( bool _v ) noexcept
{
    flags = (flags & ~flag_shown) | (_v ? flag_shown : 0);
}

void PanelDataItemVolatileData::toggle_highlight( bool _v ) noexcept
{
    flags = (flags & ~flag_highlight) | (_v ? flag_highlight : 0);
}

bool PanelDataItemVolatileData::operator==(PanelDataItemVolatileData &_rhs) const noexcept
{
    return size  == _rhs.size  &&
        flags == _rhs.flags &&
        icon  == _rhs.icon  &&
        qs_highlight_begin == _rhs.qs_highlight_begin &&
        qs_highlight_end == _rhs.qs_highlight_end;
}

bool PanelDataItemVolatileData::operator!=(PanelDataItemVolatileData &_rhs) const noexcept
{
    return !(*this == _rhs);
}
