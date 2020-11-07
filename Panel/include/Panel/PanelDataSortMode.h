// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

// 2 bytes long, OK to pass by value everywhere

namespace nc::panel::data {

struct SortMode
{
    enum Mode : signed char
    {
        SortNoSort          = 0,
        SortByName          = 1, // ascending sorting by name: A, B, C...
        SortByNameRev       = 2, // descending sorting by name: C, B, A...
        SortByExt           = 3,
        SortByExtRev        = 4,
        SortBySize          = 5, // descending sorting by size: 10Kb, 5kb, 1Kb...
        SortBySizeRev       = 6, // ascending sorting by size: 1Kb, 5Kb, 10Kb...
        SortByModTime       = 7, // descending sorting by mod time: 20/11/2016, 16/11/2016, 10/11/2016...
        SortByModTimeRev    = 8, // ascending sorting by mod time: 10/11/2016, 16/11/2016, 20/11/2016...
        SortByBirthTime     = 9, // descending sorting by crt time: 20/11/2016, 16/11/2016, 10/11/2016...
        SortByBirthTimeRev  = 10, // ascending sorting by crt time: 10/11/2016, 16/11/2016, 20/11/2016...
        SortByAddTime       = 11, // descending sorting by add time: 20/11/2016, 16/11/2016, 10/11/2016...
        SortByAddTimeRev    = 12, // ascending sorting by add time: 10/11/2016, 16/11/2016, 20/11/2016...
        SortByRawCName      = 127 // for internal usage, seems to be meaningless for human reading (sort by internal UTF8 representation)
    };
    
    Mode sort;

    /**
     * separate directories from files, like win-like
     */
    bool sep_dirs : 1;

    /**
     * treat directories like they don't have any extension at all
     */
    bool extensionless_dirs : 1;
    
    /**
     * case sensitivity when comparing filenames, ignored on Raw Sorting (SortByRawCName)
     */
    bool case_sens : 1;
    
    /**
     * try to treat filenames as numbers and use them as compare basis
     */
    bool numeric_sort : 1;
    
    SortMode() noexcept;
    bool isdirect() const noexcept;
    bool isrevert() const noexcept;
    static bool validate(Mode _mode) noexcept;
    bool operator ==(const SortMode& _r) const noexcept;
    bool operator !=(const SortMode& _r) const noexcept;
};

}
