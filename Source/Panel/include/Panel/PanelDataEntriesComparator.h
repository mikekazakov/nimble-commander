// Copyright (C) 2017-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "PanelDataSortMode.h"
#include "PanelDataItemVolatileData.h"
#include <span>

namespace nc::panel::data {

struct ExternalEntryKey;

struct ListingComparatorBase {
    ListingComparatorBase(const VFSListing &_items, std::span<const ItemVolatileData> _vd, SortMode _sort_mode);

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
    [[nodiscard]] int CompareNames(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByName(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByNameReversed(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByExension(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByExensionReversed(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByModificationTime(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByModificationTimeReversed(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByBirthTime(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByBirthTimeReversed(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByAddedTime(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByAddedTimeReversed(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByAccessTime(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByAccessTimeReversed(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessBySize(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessBySizeReversed(unsigned _1, unsigned _2) const;
    [[nodiscard]] bool IsLessByFilesystemRepresentation(unsigned _1, unsigned _2) const;
};

class ExternalListingComparator : private ListingComparatorBase
{
public:
    ExternalListingComparator(const VFSListing &_items, std::span<const ItemVolatileData> _vd, SortMode sort_mode);
    bool operator()(unsigned _1, const ExternalEntryKey &_val2) const;
};

} // namespace nc::panel::data
