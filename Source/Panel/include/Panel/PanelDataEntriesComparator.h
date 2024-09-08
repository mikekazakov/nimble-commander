// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "PanelDataSortMode.h"
#include "PanelDataItemVolatileData.h"
#include <span>

namespace nc::panel::data {

struct ExternalEntryKey;

class ListingComparatorBase
{
public:
    ListingComparatorBase(const VFSListing &_items, std::span<const ItemVolatileData> _vd, SortMode _sort_mode);

protected:
    int Compare(CFStringRef _1st, CFStringRef _2nd) const noexcept;
    int Compare(const char *_1st, const char *_2nd) const noexcept;
    static int NaturalCompare(CFStringRef _1st, CFStringRef _2nd) noexcept;
    const VFSListing &l;
    const std::span<const ItemVolatileData> vd;
    const SortMode sort_mode;
};

class IndirectListingComparator : private ListingComparatorBase
{
public:
    IndirectListingComparator(const VFSListing &_items, std::span<const ItemVolatileData> _vd, SortMode sort_mode);
    bool operator()(unsigned _1, unsigned _2) const;

private:
    int CompareNames(unsigned _1, unsigned _2) const;
    bool IsLessByName(unsigned _1, unsigned _2) const;
    bool IsLessByNameReversed(unsigned _1, unsigned _2) const;
    bool IsLessByExension(unsigned _1, unsigned _2) const;
    bool IsLessByExensionReversed(unsigned _1, unsigned _2) const;
    bool IsLessByModificationTime(unsigned _1, unsigned _2) const;
    bool IsLessByModificationTimeReversed(unsigned _1, unsigned _2) const;
    bool IsLessByBirthTime(unsigned _1, unsigned _2) const;
    bool IsLessByBirthTimeReversed(unsigned _1, unsigned _2) const;
    bool IsLessByAddedTime(unsigned _1, unsigned _2) const;
    bool IsLessByAddedTimeReversed(unsigned _1, unsigned _2) const;
    bool IsLessByAccessTime(unsigned _1, unsigned _2) const;
    bool IsLessByAccessTimeReversed(unsigned _1, unsigned _2) const;
    bool IsLessBySize(unsigned _1, unsigned _2) const;
    bool IsLessBySizeReversed(unsigned _1, unsigned _2) const;
    bool IsLessByFilesystemRepresentation(unsigned _1, unsigned _2) const;
};

class ExternalListingComparator : private ListingComparatorBase
{
public:
    ExternalListingComparator(const VFSListing &_items, std::span<const ItemVolatileData> _vd, SortMode sort_mode);
    bool operator()(unsigned _1, const ExternalEntryKey &_val2) const;
};

} // namespace nc::panel::data
