// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Layout.h"

using _ = PanelBriefViewColumnsLayout;
static_assert( sizeof(_) == 10 );

_::PanelBriefViewColumnsLayout()  noexcept:
    fixed_mode_width(150),
    fixed_amount_value(3),
    dynamic_width_min(140),
    dynamic_width_max(300),
    dynamic_width_equal(false),
    icon_scale(1),
    mode(Mode::FixedAmount)
{
}

bool _::operator ==(const _& _rhs) const noexcept
{
    return mode == _rhs.mode &&
    fixed_mode_width == _rhs.fixed_mode_width &&
    fixed_amount_value == _rhs.fixed_amount_value &&
    dynamic_width_min == _rhs.dynamic_width_min &&
    dynamic_width_max == _rhs.dynamic_width_max &&
    dynamic_width_equal == _rhs.dynamic_width_equal &&
    icon_scale == _rhs.icon_scale;
}

bool _::operator !=(const _& _rhs) const noexcept
{
    return !(*this == _rhs);
}
