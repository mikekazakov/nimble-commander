// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

// 3 modes:
// - fixed widths for columns
//      setting: this width
// - fixed amount of columns
//      setting: amount of columns
// - dynamic widths of columns
//      settings: min width, max width, should be equal

struct PanelBriefViewColumnsLayout
{
    enum class Mode : signed char {
        FixedWidth      = 0,
        FixedAmount     = 1,
        DynamicWidth    = 2
    };
    short   fixed_mode_width;
    short   fixed_amount_value;
    short   dynamic_width_min;
    short   dynamic_width_max;
    bool    dynamic_width_equal:1;
    unsigned char icon_scale:2;
    Mode    mode;
    PanelBriefViewColumnsLayout() noexcept;
    bool operator ==(const PanelBriefViewColumnsLayout& _rhs) const noexcept;
    bool operator !=(const PanelBriefViewColumnsLayout& _rhs) const noexcept;
};

