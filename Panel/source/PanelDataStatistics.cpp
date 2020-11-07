// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataStatistics.h"

namespace nc::panel::data {

bool Statistics::operator ==(const Statistics& _r) const noexcept
{
    return
    total_entries_amount      == _r.total_entries_amount      &&
    bytes_in_raw_reg_files    == _r.bytes_in_raw_reg_files    &&
    raw_reg_files_amount      == _r.raw_reg_files_amount      &&
    bytes_in_selected_entries == _r.bytes_in_selected_entries &&
    selected_entries_amount   == _r.selected_entries_amount   &&
    selected_reg_amount       == _r.selected_reg_amount       &&
    selected_dirs_amount      == _r.selected_dirs_amount;
}

bool Statistics::operator !=(const Statistics& _r) const noexcept
{
    return !(*this == _r);
}

}
