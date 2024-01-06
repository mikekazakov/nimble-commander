// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>

namespace nc::panel::data {

struct Statistics
{
    /**
     * Total entries count in listing, not including dot-dot entry.
     */
    int32_t total_entries_amount = 0;
    
    /**
     * All regular files in listing, including hidden ones.
     * Not counting directories even when it's size was calculated.
     */
    int64_t bytes_in_raw_reg_files = 0;
    
    /**
     * Amount of regular files in directory listing, regardless of sorting.
     * Includes the possibly hidden ones.
     */
    int32_t raw_reg_files_amount = 0;
    
    /**
     * Total bytes in all selected entries, including reg files and directories (if it's size was calculated).
     *
     */
    int64_t bytes_in_selected_entries = 0;
    
    // trivial
    int32_t selected_entries_amount = 0;
    int32_t selected_reg_amount = 0;
    int32_t selected_dirs_amount = 0;
    
    bool operator ==(const Statistics& _r) const noexcept;
    bool operator !=(const Statistics& _r) const noexcept;
};

}
