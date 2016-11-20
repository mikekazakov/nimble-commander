#include "PanelDataSortMode.h"

static_assert( sizeof(PanelDataSortMode) == 2 );

PanelDataSortMode::PanelDataSortMode() noexcept:
    sort(SortByRawCName),
    sep_dirs(false),
    case_sens(false),
    numeric_sort(false)
{}

bool PanelDataSortMode::isdirect() const noexcept
{
    return sort == SortByName ||
           sort == SortByExt ||
           sort == SortBySize ||
           sort == SortByModTime ||
           sort == SortByBirthTime;
}

bool PanelDataSortMode::isrevert() const noexcept
{
    return sort == SortByNameRev ||
           sort == SortByExtRev ||
           sort == SortBySizeRev ||
           sort == SortByModTimeRev ||
           sort == SortByBirthTimeRev;
}

bool PanelDataSortMode::validate(Mode _mode) noexcept
{
    return _mode == SortNoSort ||
    _mode == SortByName ||
    _mode == SortByNameRev ||
    _mode == SortByExt ||
    _mode == SortByExtRev ||
    _mode == SortBySize ||
    _mode == SortBySizeRev ||
    _mode == SortByModTime ||
    _mode == SortByModTimeRev ||
    _mode == SortByBirthTime ||
    _mode == SortByBirthTimeRev ||
    _mode == SortByAddTime ||
    _mode == SortByAddTimeRev ;
}

bool PanelDataSortMode::operator ==(const PanelDataSortMode& _r) const noexcept
{
    return sort == _r.sort &&
           sep_dirs == _r.sep_dirs &&
           case_sens == _r.case_sens &&
           numeric_sort == _r.numeric_sort;
}

bool PanelDataSortMode::operator !=(const PanelDataSortMode& _r) const noexcept
{
    return !(*this == _r);
}
