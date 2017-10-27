// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataSortMode.h"

namespace nc::panel::data {

static_assert( sizeof(SortMode) == 2 );

SortMode::SortMode() noexcept:
    sort(SortByRawCName),
    sep_dirs(false),
    case_sens(false),
    numeric_sort(false),
    extensionless_dirs(false)
{}

bool SortMode::isdirect() const noexcept
{
    return sort == SortByName ||
           sort == SortByExt ||
           sort == SortBySize ||
           sort == SortByModTime ||
           sort == SortByBirthTime;
}

bool SortMode::isrevert() const noexcept
{
    return sort == SortByNameRev ||
           sort == SortByExtRev ||
           sort == SortBySizeRev ||
           sort == SortByModTimeRev ||
           sort == SortByBirthTimeRev;
}

bool SortMode::validate(Mode _mode) noexcept
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

bool SortMode::operator ==(const SortMode& _r) const noexcept
{
    return sort == _r.sort &&
           sep_dirs == _r.sep_dirs &&
           case_sens == _r.case_sens &&
           numeric_sort == _r.numeric_sort &&
           extensionless_dirs == _r.extensionless_dirs;
}

bool SortMode::operator !=(const SortMode& _r) const noexcept
{
    return !(*this == _r);
}

}
