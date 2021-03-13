// Copyright (C) 2016-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::panel::data {

// 2 bytes long, OK to pass by value everywhere
struct SortMode {
    // Values in this enumeration should be stable - they are used for raw serialization
    enum Mode : signed char
    {
        SortNoSort = 0,

        // ascending sorting by name: A, B, C...
        SortByName = 1,

        // descending sorting by name: C, B, A...
        SortByNameRev = 2,
        
        // ascending sorting by extension: .dmg, .json, .pdf...
        SortByExt = 3,
        
        // descending sorting by extension: .pdf, .json, .dmg ...
        SortByExtRev = 4,

        // descending sorting by size: 10Kb, 5kb, 1Kb...
        SortBySize = 5,

        // ascending sorting by size: 1Kb, 5Kb, 10Kb...
        SortBySizeRev = 6,

        // descending sorting by mod time: 20/11/2016, 16/11/2016, 10/11/2016...
        SortByModTime = 7,

        // ascending sorting by mod time: 10/11/2016, 16/11/2016, 20/11/2016...
        SortByModTimeRev = 8,

        // descending sorting by crt time: 20/11/2016, 16/11/2016, 10/11/2016...
        SortByBirthTime = 9,

        // ascending sorting by crt time: 10/11/2016, 16/11/2016, 20/11/2016...
        SortByBirthTimeRev = 10,

        // descending sorting by add time: 20/11/2016, 16/11/2016, 10/11/2016...
        SortByAddTime = 11,

        // ascending sorting by add time: 10/11/2016, 16/11/2016, 20/11/2016...
        SortByAddTimeRev = 12,

        // descending sorting by access time: 20/11/2016, 16/11/2016, 10/11/2016...
        SortByAccessTime = 13,

        // ascending sorting by access time: 10/11/2016, 16/11/2016, 20/11/2016...
        SortByAccessTimeRev = 14,

        // for internal usage, seems to be meaningless for human reading (sort by internal UTF8
        // representation)
        SortByRawCName = 127
    };
    
    // sorting order
    Mode sort = SortByRawCName;

    // separate directories from files, like win-like
    bool sep_dirs : 1 = false;

    // treat directories like they don't have any extension at all
    bool extensionless_dirs : 1 = false;

    // case sensitivity when comparing filenames, ignored on Raw Sorting (SortByRawCName)
    bool case_sens : 1 = false;

    // try to treat filenames as numbers and use them as compare basis
    bool numeric_sort : 1 = false;

    bool isdirect() const noexcept;
    bool isrevert() const noexcept;
    static bool validate(Mode _mode) noexcept;
    bool operator==(const SortMode &_r) const noexcept;
    bool operator!=(const SortMode &_r) const noexcept;
};

} // namespace nc::panel::data
