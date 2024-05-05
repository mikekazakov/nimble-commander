// Copyright (C) 2014-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/dirent.h>
#include <VFS/VFS.h>
#include <VFS/VFSListingInput.h>
#include "PanelDataEntriesComparator.h"
#include "PanelDataItemVolatileData.h"
#include <memory>
#include <span>
#include "Tests.h"

#define PREFIX "IndirectListingComparator "

using namespace nc;
using namespace nc::base;
using namespace nc::panel::data;

namespace {
struct DummyListingEntry {
    std::string name;
    std::optional<std::string> display_name;
    bool is_directory = false;
};
} // namespace

static VFSListingPtr ProduceDummyListing(std::span<const DummyListingEntry> _entries)
{
    vfs::ListingInput l;

    l.directories.reset(variable_container<>::type::common);
    l.directories[0] = "/";

    l.hosts.reset(variable_container<>::type::common);
    l.hosts[0] = VFSHost::DummyHost();

    size_t index = 0;
    for( auto &i : _entries ) {
        l.filenames.emplace_back(i.name);
        l.unix_modes.emplace_back(i.is_directory ? (S_IRUSR | S_IWUSR | S_IFDIR) : (S_IRUSR | S_IWUSR | S_IFREG));
        l.unix_types.emplace_back(i.is_directory ? DT_DIR : DT_REG);
        if( i.display_name )
            l.display_filenames.insert(index, *i.display_name);
        ++index;
    }
    return VFSListing::Build(std::move(l));
}

TEST_CASE(PREFIX "SortByName")
{
    std::array<DummyListingEntry, 5> entries;
    entries[0].name = "A";
    entries[1].name = "B";
    entries[1].is_directory = true;
    entries[2].name = "A";
    entries[2].display_name = "C";
    entries[2].is_directory = true;
    entries[3].name = "B";
    entries[3].display_name = "b";
    entries[4].name = "b";
    entries[4].is_directory = true;
    const auto listing = ProduceDummyListing(entries);
    const std::array<ItemVolatileData, 5> vd;

    SortMode sort;
    sort.sort = SortMode::SortByName;

    SECTION("Default flags")
    {
        const IndirectListingComparator cmp(*listing, vd, sort);
        CHECK(cmp(0, 0) == false); // A vs A
        CHECK(cmp(0, 1) == true);  // A vs B'
        CHECK(cmp(1, 0) == false); // B' vs A
        CHECK(cmp(0, 2) == true);  // A vs A(C)'
        CHECK(cmp(2, 0) == false); // A(C)' vs A
        CHECK(cmp(2, 2) == false); // A(C)' vs A(C)'
        CHECK(cmp(1, 3) == false); // B' vs B(b)
        CHECK(cmp(3, 1) == false); // B(b) vs B'
        CHECK(cmp(3, 4) == false); // B(b) vs b'
        CHECK(cmp(4, 3) == false); // b' vs B(b)
    }
    SECTION("Case-sensitive")
    {
        sort.case_sens = true;
        const IndirectListingComparator cmp(*listing, vd, sort);
        CHECK(cmp(0, 0) == false); // A vs A
        CHECK(cmp(0, 1) == true);  // A vs B'
        CHECK(cmp(1, 0) == false); // B' vs A
        CHECK(cmp(0, 2) == true);  // A vs A(C)'
        CHECK(cmp(2, 0) == false); // A(C)' vs A
        CHECK(cmp(2, 2) == false); // A(C)' vs A(C)'
        CHECK(cmp(1, 3) == true);  // B' vs B(b)
        CHECK(cmp(3, 1) == false); // B(b) vs B'
        CHECK(cmp(3, 4) == false); // B(b) vs b'
        CHECK(cmp(4, 3) == false); // b' vs B(b)
    }
    SECTION("Separate directories")
    {
        sort.sep_dirs = true;
        const IndirectListingComparator cmp(*listing, vd, sort);
        CHECK(cmp(0, 0) == false); // A vs A
        CHECK(cmp(0, 1) == false); // A vs B'
        CHECK(cmp(1, 0) == true);  // B' vs A
        CHECK(cmp(0, 2) == false); // A vs A(C)'
        CHECK(cmp(2, 0) == true);  // A(C)' vs A
        CHECK(cmp(2, 2) == false); // A(C)' vs A(C)'
        CHECK(cmp(1, 3) == true);  // B' vs B(b)
        CHECK(cmp(3, 1) == false); // B(b) vs B'
        CHECK(cmp(3, 4) == false); // B(b) vs b'
        CHECK(cmp(4, 3) == true);  // b' vs B(b)
    }
    SECTION("Case-sensitive, separate directories")
    {
        sort.case_sens = true;
        sort.sep_dirs = true;
        const IndirectListingComparator cmp(*listing, vd, sort);
        CHECK(cmp(0, 0) == false); // A vs A
        CHECK(cmp(0, 1) == false); // A vs B'
        CHECK(cmp(1, 0) == true);  // B' vs A
        CHECK(cmp(0, 2) == false); // A vs A(C)'
        CHECK(cmp(2, 0) == true);  // A(C)' vs A
        CHECK(cmp(2, 2) == false); // A(C)' vs A(C)'
        CHECK(cmp(1, 3) == true);  // B' vs B(b)
        CHECK(cmp(3, 1) == false); // B(b) vs B'
        CHECK(cmp(3, 4) == false); // B(b) vs b'
        CHECK(cmp(4, 3) == true);  // b' vs B(b)
    }
}

TEST_CASE(PREFIX "SortByNameRev")
{
    std::array<DummyListingEntry, 5> entries;
    entries[0].name = "A";
    entries[1].name = "B";
    entries[1].is_directory = true;
    entries[2].name = "A";
    entries[2].display_name = "C";
    entries[2].is_directory = true;
    entries[3].name = "B";
    entries[3].display_name = "b";
    entries[4].name = "b";
    entries[4].is_directory = true;
    const auto listing = ProduceDummyListing(entries);
    const std::array<ItemVolatileData, 5> vd;

    SortMode sort;
    sort.sort = SortMode::SortByNameRev;

    SECTION("Default flags")
    {
        const IndirectListingComparator cmp(*listing, vd, sort);
        CHECK(cmp(0, 0) == false); // A vs A
        CHECK(cmp(0, 1) == false); // A vs B'
        CHECK(cmp(1, 0) == true);  // B' vs A
        CHECK(cmp(0, 2) == false); // A vs A(C)'
        CHECK(cmp(2, 0) == true);  // A(C)' vs A
        CHECK(cmp(2, 2) == false); // A(C)' vs A(C)'
        CHECK(cmp(1, 3) == false); // B' vs B(b)
        CHECK(cmp(3, 1) == false); // B(b) vs B'
        CHECK(cmp(3, 4) == false); // B(b) vs b'
        CHECK(cmp(4, 3) == false); // b' vs B(b)
    }
    SECTION("Case-sensitive")
    {
        sort.case_sens = true;
        const IndirectListingComparator cmp(*listing, vd, sort);
        CHECK(cmp(0, 0) == false); // A vs A
        CHECK(cmp(0, 1) == false); // A vs B'
        CHECK(cmp(1, 0) == true);  // B' vs A
        CHECK(cmp(0, 2) == false); // A vs A(C)'
        CHECK(cmp(2, 0) == true);  // A(C)' vs A
        CHECK(cmp(2, 2) == false); // A(C)' vs A(C)'
        CHECK(cmp(1, 3) == false); // B' vs B(b)
        CHECK(cmp(3, 1) == true);  // B(b) vs B'
        CHECK(cmp(3, 4) == false); // B(b) vs b'
        CHECK(cmp(4, 3) == false); // b' vs B(b)
    }
    SECTION("Separate directories")
    {
        sort.sep_dirs = true;
        const IndirectListingComparator cmp(*listing, vd, sort);
        CHECK(cmp(0, 0) == false); // A vs A
        CHECK(cmp(0, 1) == false); // A vs B'
        CHECK(cmp(1, 0) == true);  // B' vs A
        CHECK(cmp(0, 2) == false); // A vs A(C)'
        CHECK(cmp(2, 0) == true);  // A(C)' vs A
        CHECK(cmp(2, 2) == false); // A(C)' vs A(C)'
        CHECK(cmp(1, 3) == true);  // B' vs B(b)
        CHECK(cmp(3, 1) == false); // B(b) vs B'
        CHECK(cmp(3, 4) == false); // B(b) vs b'
        CHECK(cmp(4, 3) == true);  // b' vs B(b)
    }
    SECTION("Case-sensitive, separate directories")
    {
        sort.case_sens = true;
        sort.sep_dirs = true;
        const IndirectListingComparator cmp(*listing, vd, sort);
        CHECK(cmp(0, 0) == false); // A vs A
        CHECK(cmp(0, 1) == false); // A vs B'
        CHECK(cmp(1, 0) == true);  // B' vs A
        CHECK(cmp(0, 2) == false); // A vs A(C)'
        CHECK(cmp(2, 0) == true);  // A(C)' vs A
        CHECK(cmp(2, 2) == false); // A(C)' vs A(C)'
        CHECK(cmp(1, 3) == true);  // B' vs B(b)
        CHECK(cmp(3, 1) == false); // B(b) vs B'
        CHECK(cmp(3, 4) == false); // B(b) vs b'
        CHECK(cmp(4, 3) == true);  // b' vs B(b)
    }
}
