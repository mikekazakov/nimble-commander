#include "Layout.h"

static_assert( sizeof(PanelBriefViewColumnsLayout) == 10 );

bool PanelBriefViewColumnsLayout::operator ==(const PanelBriefViewColumnsLayout& _rhs) const noexcept
{
    return mode == _rhs.mode &&
    fixed_mode_width == _rhs.fixed_mode_width &&
    fixed_amount_value == _rhs.fixed_amount_value &&
    dynamic_width_min == _rhs.dynamic_width_min &&
    dynamic_width_max == _rhs.dynamic_width_max &&
    dynamic_width_equal == _rhs.dynamic_width_equal;
}

bool PanelBriefViewColumnsLayout::operator !=(const PanelBriefViewColumnsLayout& _rhs) const noexcept
{
    return !(*this == _rhs);
}

