#pragma once

// 2 bytes long, OK to pass by value everywhere
struct PanelDataSortMode
{
    enum Mode : signed char
    {
        SortNoSort          = 0,
        SortByName          = 1,
        SortByNameRev       = 2,
        SortByExt           = 3,
        SortByExtRev        = 4,
        SortBySize          = 5,
        SortBySizeRev       = 6,
        SortByModTime       = 7,
        SortByModTimeRev    = 8,
        SortByBirthTime     = 9,
        SortByBirthTimeRev  = 10,
        SortByAddTime       = 11,
        SortByAddTimeRev    = 12,
        SortByRawCName      = 127 // for internal usage, seems to be meaningless for human reading (sort by internal UTF8 representation)
    };
    
    Mode sort;
    bool sep_dirs : 1;      // separate directories from files, like win-like
    bool case_sens : 1;     // case sensitivity when comparing filenames, ignored on Raw Sorting (SortByRawCName)
    bool numeric_sort : 1;  // try to treat filenames as numbers and use them as compare basis
    
    PanelDataSortMode() noexcept;
    bool isdirect() const noexcept;
    bool isrevert() const noexcept;
    static bool validate(Mode _mode) noexcept;
    bool operator ==(const PanelDataSortMode& _r) const noexcept;
    bool operator !=(const PanelDataSortMode& _r) const noexcept;
};
