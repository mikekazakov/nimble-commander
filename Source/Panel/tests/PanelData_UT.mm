// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/dirent.h>
#include <VFS/VFS.h>
#include <VFS/VFSListingInput.h>
#include "PanelData.h"
#include "PanelDataItemVolatileData.h"
#include "PanelDataSelection.h"
#include <memory>
#include <set>
#include "Tests.h"

#define PREFIX "PanelData "

using namespace nc;
using namespace nc::base;
using namespace nc::panel;
using data::ItemVolatileData;
using data::Model;

static VFSListingPtr ProduceDummyListing(const std::vector<std::string> &_filenames)
{
    vfs::ListingInput l;

    l.directories.reset(variable_container<>::type::common);
    l.directories[0] = "/";

    l.hosts.reset(variable_container<>::type::common);
    l.hosts[0] = VFSHost::DummyHost();

    for( auto &i : _filenames ) {
        l.filenames.emplace_back(i);
        l.unix_modes.emplace_back(0);
        l.unix_types.emplace_back(0);
    }

    return VFSListing::Build(std::move(l));
}

// filename, is_directory
static VFSListingPtr ProduceDummyListing(const std::vector<std::tuple<std::string, bool>> &_entries)
{
    vfs::ListingInput l;

    l.directories.reset(variable_container<>::type::common);
    l.directories[0] = "/";

    l.hosts.reset(variable_container<>::type::common);
    l.hosts[0] = VFSHost::DummyHost();

    for( auto &i : _entries ) {
        const auto &filename = std::get<0>(i);
        const auto is_directory = std::get<1>(i);
        l.filenames.emplace_back(filename);
        l.unix_modes.emplace_back(is_directory ? (S_IRUSR | S_IWUSR | S_IFDIR) : (S_IRUSR | S_IWUSR | S_IFREG));
        l.unix_types.emplace_back(is_directory ? DT_DIR : DT_REG);
    }
    return VFSListing::Build(std::move(l));
}

// directory, filename, size
static VFSListingPtr
ProduceNonUniformDummyListing(const std::vector<std::tuple<std::string, std::string, size_t>> &_entries)
{
    vfs::ListingInput l;
    l.directories.reset(variable_container<>::type::dense);
    l.hosts.reset(variable_container<>::type::dense);
    for( size_t i = 0; i < _entries.size(); ++i ) {
        l.directories.insert(i, std::get<0>(_entries[i]));
        l.hosts.insert(i, VFSHost::DummyHost());
        l.filenames.emplace_back(std::get<1>(_entries[i]));
        l.unix_modes.emplace_back(0);
        l.unix_types.emplace_back(0);
        l.sizes.insert(i, std::get<2>(_entries[i]));
    }
    return VFSListing::Build(std::move(l));
}

TEST_CASE(PREFIX "Empty model")
{
    const Model model;
    CHECK(model.IsLoaded() == false);
    CHECK(model.Listing().Count() == 0);
    CHECK(model.RawEntriesCount() == 0);
}

TEST_CASE(PREFIX "Load")
{
    const auto listing = ProduceDummyListing(std::vector<std::tuple<std::string, bool>>{
        {"..", true}, {"file1", false}, {"File2", false}, {"file3", false}, {"Dir1", true}, {"dir2", true}});
    Model model;
    model.Load(listing, Model::PanelType::Directory);

    CHECK(model.IsLoaded() == true);
    CHECK(&model.Listing() == listing.get());
    CHECK(model.ListingPtr() == listing);
    CHECK(model.RawEntriesCount() == 6);
    CHECK(model.SortedEntriesCount() == 6);
}

TEST_CASE(PREFIX "RawIndicesForName")
{
    SECTION("Filled")
    {
        const auto listing = ProduceDummyListing(std::vector<std::string>{"a", "b", "c", "a", "A", "b", "a", "c", "a"});
        Model model;
        model.Load(listing, Model::PanelType::Directory);
        {
            const auto inds = model.RawIndicesForName("a");
            CHECK(std::set<unsigned>(inds.begin(), inds.end()) == std::set<unsigned>{0, 3, 6, 8});
        }
        {
            const auto inds = model.RawIndicesForName("c");
            CHECK(std::set<unsigned>(inds.begin(), inds.end()) == std::set<unsigned>{2, 7});
        }

        {
            const auto inds = model.RawIndicesForName("A");
            CHECK(std::set<unsigned>(inds.begin(), inds.end()) == std::set<unsigned>{4});
        }
        {
            const auto inds = model.RawIndicesForName("nope");
            CHECK(inds.empty());
        }
    }
    SECTION("Empty")
    {
        const Model model;
        CHECK(model.RawIndicesForName("a").empty());
    }
}

TEST_CASE(PREFIX "SortedIndexForRawIndex")
{
    SECTION("Empty")
    {
        const Model model;
        CHECK(model.SortedIndexForRawIndex(-1) == -1);
        CHECK(model.SortedIndexForRawIndex(0) == -1);
    }
    SECTION("Filled, no hard filtering")
    {
        const auto listing = ProduceDummyListing(std::vector<std::string>{"a", "b", "c", "a", "A", "b", "a", "c", "a"});
        data::SortMode sorting;
        sorting.sort = data::SortMode::SortByName;

        Model model;
        model.SetSortMode(sorting);
        model.Load(listing, Model::PanelType::Directory);

        CHECK(model.SortedIndexForRawIndex(-1) == -1);
        CHECK(model.SortedIndexForRawIndex(0) == 0);
        CHECK(model.SortedIndexForRawIndex(1) == 5);
        CHECK(model.SortedIndexForRawIndex(2) == 7);
        CHECK(model.SortedIndexForRawIndex(3) == 1);
        CHECK(model.SortedIndexForRawIndex(4) == 2);
        CHECK(model.SortedIndexForRawIndex(5) == 6);
        CHECK(model.SortedIndexForRawIndex(6) == 3);
        CHECK(model.SortedIndexForRawIndex(7) == 8);
        CHECK(model.SortedIndexForRawIndex(8) == 4);
        CHECK(model.SortedIndexForRawIndex(9) == -1);
    }
    SECTION("Filled, hard filtering")
    {
        const auto listing = ProduceDummyListing(std::vector<std::string>{"a", "b", "c", "a", "A", "b", "a", "c", "a"});
        data::SortMode sorting;
        sorting.sort = data::SortMode::SortByName;

        data::TextualFilter textual_filter;
        textual_filter.text = @"a";
        textual_filter.type = data::TextualFilter::Anywhere;

        data::HardFilter filter;
        filter.text = textual_filter;

        Model model;
        model.SetSortMode(sorting);
        model.SetHardFiltering(filter);
        model.Load(listing, Model::PanelType::Directory);

        CHECK(model.SortedIndexForRawIndex(-1) == -1);
        CHECK(model.SortedIndexForRawIndex(0) == 0);
        CHECK(model.SortedIndexForRawIndex(1) == -1);
        CHECK(model.SortedIndexForRawIndex(2) == -1);
        CHECK(model.SortedIndexForRawIndex(3) == 1);
        CHECK(model.SortedIndexForRawIndex(4) == 2);
        CHECK(model.SortedIndexForRawIndex(5) == -1);
        CHECK(model.SortedIndexForRawIndex(6) == 3);
        CHECK(model.SortedIndexForRawIndex(7) == -1);
        CHECK(model.SortedIndexForRawIndex(8) == 4);
        CHECK(model.SortedIndexForRawIndex(9) == -1);
    }
}

TEST_CASE(PREFIX "SortPositionOfEntry")
{
    const auto l1 = ProduceDummyListing(std::vector<std::string>{"c", "b", "a"});
    const auto l2 = ProduceDummyListing(std::vector<std::string>{"c", "b", "a"});
    data::SortMode sorting;
    sorting.sort = data::SortMode::SortByName;

    // first no filtering, sort by name
    Model model;
    model.SetSortMode(sorting);
    model.Load(l1, Model::PanelType::Directory);
    CHECK(model.SortPositionOfEntry(l1->Item(0)) == 2);
    CHECK(model.SortPositionOfEntry(l1->Item(1)) == 1);
    CHECK(model.SortPositionOfEntry(l1->Item(2)) == 0);
    CHECK(model.SortPositionOfEntry(l2->Item(0)) == -1);
    CHECK(model.SortPositionOfEntry(l2->Item(1)) == -1);
    CHECK(model.SortPositionOfEntry(l2->Item(2)) == -1);

    // then check with hard filtering
    data::TextualFilter textual_filter;
    textual_filter.text = @"b";
    data::HardFilter filter;
    filter.text = textual_filter;
    model.SetHardFiltering(filter);
    CHECK(model.SortPositionOfEntry(l1->Item(0)) == -1);
    CHECK(model.SortPositionOfEntry(l1->Item(1)) == 0);
    CHECK(model.SortPositionOfEntry(l1->Item(2)) == -1);
    CHECK(model.SortPositionOfEntry(l2->Item(0)) == -1);
    CHECK(model.SortPositionOfEntry(l2->Item(1)) == -1);
    CHECK(model.SortPositionOfEntry(l2->Item(2)) == -1);
}

TEST_CASE(PREFIX "Basic")
{
    const auto strings = std::vector<std::string>{"..",
                                                  "some filename",
                                                  "another filename",
                                                  reinterpret_cast<const char *>(u8"even written with какие-то буквы")};
    const auto listing = ProduceDummyListing(strings);

    data::Model data;
    data.Load(listing, data::Model::PanelType::Directory);

    // testing raw C sorting facility
    for( unsigned i = 0; i < listing->Count(); ++i )
        CHECK(data.RawIndexForName(listing->Filename(i)) == static_cast<int>(i));

    // testing basic sorting (direct by filename)
    auto sorting = data.SortMode();
    sorting.sort = data::SortMode::SortByName;
    data.SetSortMode(sorting);

    CHECK(data.SortedIndexForName(listing->Filename(0)) == 0);
    CHECK(data.SortedIndexForName(listing->Filename(2)) == 1);
    CHECK(data.SortedIndexForName(listing->Filename(3)) == 2);
    CHECK(data.SortedIndexForName(listing->Filename(1)) == 3);
}

TEST_CASE(PREFIX "SortingWithCases")
{
    const auto strings = std::vector<std::string>{reinterpret_cast<const char *>(u8"аааа"),
                                                  reinterpret_cast<const char *>(u8"бббб"),
                                                  reinterpret_cast<const char *>(u8"АААА"),
                                                  reinterpret_cast<const char *>(u8"ББББ")};
    const auto listing = ProduceDummyListing(strings);

    data::Model data;
    auto sorting = data.SortMode();
    sorting.sort = data::SortMode::SortByName;
    data.SetSortMode(sorting);
    data.Load(listing, data::Model::PanelType::Directory);

    CHECK(data.SortedIndexForName(listing->Item(0).FilenameC()) == 0);
    CHECK(data.SortedIndexForName(listing->Item(2).FilenameC()) == 1);
    CHECK(data.SortedIndexForName(listing->Item(1).FilenameC()) == 2);
    CHECK(data.SortedIndexForName(listing->Item(3).FilenameC()) == 3);

    sorting.collation = data::SortMode::Collation::CaseSensitive;
    data.SetSortMode(sorting);
    CHECK(data.SortedIndexForName(listing->Item(2).FilenameC()) == 0);
    CHECK(data.SortedIndexForName(listing->Item(3).FilenameC()) == 1);
    CHECK(data.SortedIndexForName(listing->Item(0).FilenameC()) == 2);
    CHECK(data.SortedIndexForName(listing->Item(1).FilenameC()) == 3);
}

TEST_CASE(PREFIX "HardFiltering")
{
    // just my home dir below
    const auto strings = std::vector<std::string>{"..",
                                                  ".cache",
                                                  reinterpret_cast<const char *>(u8"АААА"),
                                                  reinterpret_cast<const char *>(u8"ББББ"),
                                                  ".config",
                                                  ".cups",
                                                  ".dropbox",
                                                  ".dvdcss",
                                                  ".local",
                                                  ".mplayer",
                                                  ".ssh",
                                                  ".subversion",
                                                  ".Trash",
                                                  "Applications",
                                                  "Another app",
                                                  "Another app number two",
                                                  "Applications (Parallels)",
                                                  reinterpret_cast<const char *>(u8"что-то на русском языке"),
                                                  reinterpret_cast<const char *>(u8"ЕЩЕ РУССКИЙ ЯЗЫК"),
                                                  "Desktop",
                                                  "Documents",
                                                  "Downloads",
                                                  "Dropbox",
                                                  "Games",
                                                  "Library",
                                                  "Movies",
                                                  "Music",
                                                  "Pictures",
                                                  "Public"};
    const auto listing = ProduceDummyListing(strings);

    const auto empty_listing = VFSListing::EmptyListing();

    const auto almost_empty_listing =
        ProduceDummyListing(std::vector<std::string>{reinterpret_cast<const char *>(u8"какой-то файл")});

    data::Model data;
    auto sorting = data.SortMode();
    sorting.sort = data::SortMode::SortByName;
    data.SetSortMode(sorting);

    auto filtering = data.HardFiltering();
    filtering.show_hidden = true;
    data.SetHardFiltering(filtering);

    data.Load(listing, data::Model::PanelType::Directory);
    CHECK(data.SortedIndexForName("..") == 0);
    CHECK(data.SortedIndexForName(".Trash") >= 0);
    CHECK(data.SortedIndexForName("Games") >= 0);

    filtering.show_hidden = false;
    data.SetHardFiltering(filtering);
    CHECK(data.SortedIndexForName("..") == 0);
    CHECK(data.SortedIndexForName(".Trash") < 0);
    CHECK(data.SortedIndexForName("Games") >= 0);

    filtering.text.type = data::TextualFilter::Anywhere;
    filtering.text.text = @"D";
    data.SetHardFiltering(filtering);

    CHECK(data.SortedIndexForName("..") == 0);
    CHECK(data.SortedIndexForName(".Trash") < 0);
    CHECK(data.SortedIndexForName("Games") < 0);
    CHECK(data.SortedIndexForName("Desktop") >= 0);

    filtering.text.text = @"a very long-long filtering string that will never leave any file even "
                          @"с другим языком внутри";
    data.SetHardFiltering(filtering);
    CHECK(data.SortedIndexForName("..") == 0);
    CHECK(data.SortedIndexForName("Desktop") < 0);
    CHECK(data.SortedDirectoryEntries().size() == 1);

    // now test what will happen on empty listing
    data.Load(empty_listing, data::Model::PanelType::Directory);
    CHECK(data.SortedIndexForName("..") < 0);

    // now test what will happen on almost empty listing (will became empty after filtering)
    data.Load(almost_empty_listing, data::Model::PanelType::Directory);
    CHECK(data.SortedIndexForName("..") < 0);

    // now more comples situations
    filtering.text.text = @"IC";
    data.SetHardFiltering(filtering);
    auto count = listing->Count();
    data.Load(listing, data::Model::PanelType::Directory);
    CHECK(data.SortedIndexForName("..") == 0);
    CHECK(data.SortedIndexForName("Music") >= 0);
    CHECK(data.SortedIndexForName("Pictures") >= 0);
    CHECK(data.SortedIndexForName("Public") >= 0);
    CHECK(data.SortedDirectoryEntries().size() == 6);

    filtering.text.text = @"русск";
    data.SetHardFiltering(filtering);
    CHECK(data.SortedIndexForName("..") == 0);
    CHECK(data.SortedIndexForName("Pictures") < 0);
    CHECK(data.SortedIndexForName("Public") < 0);
    CHECK(data.SortedIndexForName(@"что-то на русском языке".fileSystemRepresentation) >= 0);
    CHECK(data.SortedIndexForName(reinterpret_cast<const char *>(u8"ЕЩЕ РУССКИЙ ЯЗЫК")) >= 0);

    filtering.text.type = data::TextualFilter::Beginning;
    filtering.text.text = @"APP";
    data.SetHardFiltering(filtering);
    CHECK(data.SortedIndexForName("..") == 0);
    CHECK(data.SortedIndexForName("Pictures") < 0);
    CHECK(data.SortedIndexForName("Public") < 0);
    CHECK(data.SortedIndexForName("Applications") > 0);
    CHECK(data.SortedIndexForName("Applications (Parallels)") > 0);
    CHECK(data.SortedIndexForName("Another app") < 0);
    CHECK(data.SortedIndexForName("Another app number two") < 0);

    // test buggy filtering with @"" string
    filtering.text.type = data::TextualFilter::Beginning;
    filtering.text.text = @"";
    filtering.show_hidden = true;
    data.SetHardFiltering(filtering);
    CHECK(data.SortedIndexForName("..") == 0);
    CHECK(data.SortedDirectoryEntries().size() == count);
}

TEST_CASE(PREFIX "HardFiltering, edge case - emply panel")
{
    const auto strings = std::vector<std::string>{"aaa", "bbb"};
    const auto listing = ProduceDummyListing(strings);

    data::Model data;
    auto sorting = data.SortMode();
    sorting.sort = data::SortMode::SortByName;
    data.SetSortMode(sorting);

    auto filtering = data.HardFiltering();
    filtering.show_hidden = true;
    data.SetHardFiltering(filtering);

    data.Load(listing, data::Model::PanelType::Directory);
    CHECK(data.SortedIndexForName("aaa") == 0);
    CHECK(data.SortedIndexForName("bbb") == 1);

    filtering.text.text = @"nonsense";
    data.SetHardFiltering(filtering);
    CHECK(data.SortedEntriesCount() == 0);
    CHECK(data.SortedIndexForName("aaa") == -1);
    CHECK(data.SortedIndexForName("bbb") == -1);
}

TEST_CASE(PREFIX "SelectionWithExtension")
{
    data::Model data;
    const data::SelectionBuilder selector{data, true};
    const data::SelectionBuilder selector_w_dirs{data, false};

    const auto bin_listing = ProduceDummyListing(std::vector<std::string>{
        "..",   "[",     "bash", "cat",  "chmod",    "cp",        "csh", "dash",      "date", "dd",
        "df",   "echo",  "ed",   "expr", "hostname", "kill",      "ksh", "launchctl", "link", "ln",
        "ls",   "mkdir", "mv",   "pax",  "ps",       "pwd",       "rm",  "rmdir",     "sh",   "sleep",
        "stty", "sync",  "tcsh", "test", "unlink",   "wait4path", "zsh"});
    data.Load(bin_listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted(selector.SelectionByExtension("", true));
    CHECK(data.Stats().selected_entries_amount == 36);

    const auto man1_listing = ProduceDummyListing(std::vector<std::string>{"..",
                                                                           "gzexe.1",
                                                                           "splain5.28.1",
                                                                           "hpmdiagnose.1",
                                                                           "perl5142delta.1",
                                                                           "perlfaq.1",
                                                                           "bundle-platform.1",
                                                                           "env.1",
                                                                           "head.1",
                                                                           "cpan5.18.1",
                                                                           "perlembed5.28.1",
                                                                           "gzip.1",
                                                                           "unvis.1",
                                                                           "unzipsfx.1",
                                                                           "perlxstypemap5.18.1",
                                                                           "assetutil.1",
                                                                           "ipcs.1",
                                                                           "perlmodlib5.28.1",
                                                                           "dapptrace.1m",
                                                                           "quota.1"});
    data.Load(man1_listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted(selector.SelectionByExtension("1", true));
    CHECK(data.Stats().selected_entries_amount == 18);

    const auto servs_listing =
        ProduceDummyListing(std::vector<std::tuple<std::string, bool>>{{"..", true},
                                                                       {".disk_label", false},
                                                                       {".disk_label_2x", false},
                                                                       {"AOS.bundle", true},
                                                                       {"APFSUserAgent", false},
                                                                       {"AVB Audio Configuration.app", true},
                                                                       {"AddPrinter.app", true},
                                                                       {"AddressBookUrlForwarder.app", true},
                                                                       {"AirPlayUIAgent.app", true},
                                                                       {"AirPort Base Station Agent.app", true},
                                                                       {"AppleFileServer.app", true},
                                                                       {"AppleScript Utility.app", true},
                                                                       {"ApplicationFirewall.bundle", true},
                                                                       {"Applications", true},
                                                                       {"Automator Installer.app", true},
                                                                       {"Bluetooth Setup Assistant.app", true},
                                                                       {"BluetoothUIServer.app", true},
                                                                       {"BridgeRestoreVersion.plist", false}});
    data.Load(servs_listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted(selector.SelectionByExtension("app", true));
    CHECK(data.Stats().selected_entries_amount == 0);

    data.Load(servs_listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted(selector_w_dirs.SelectionByExtension("app", true));
    CHECK(data.Stats().selected_entries_amount == 10);

    data.Load(servs_listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted(selector_w_dirs.SelectionByExtension("App", true));
    CHECK(data.Stats().selected_entries_amount == 10);

    data.Load(servs_listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted(selector_w_dirs.SelectionByExtension("ApP", true));
    CHECK(data.Stats().selected_entries_amount == 10);

    data.Load(servs_listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted(selector_w_dirs.SelectionByExtension("APP", true));
    CHECK(data.Stats().selected_entries_amount == 10);
}

TEST_CASE(PREFIX "DirectorySorting")
{
    const std::vector<std::tuple<std::string, bool>> entries = {
        {{"Alpha.2", true}, {"Bravo.1", true}, {"Charlie.3", true}}};
    auto listing = ProduceDummyListing(entries);

    data::Model data;
    data.Load(listing, data::Model::PanelType::Directory);

    data::SortMode sorting;
    sorting.sort = data::SortMode::SortByExt;
    data.SetSortMode(sorting);
    CHECK(data.EntryAtSortPosition(0).Filename() == "Bravo.1");
    CHECK(data.EntryAtSortPosition(1).Filename() == "Alpha.2");
    CHECK(data.EntryAtSortPosition(2).Filename() == "Charlie.3");

    sorting.extensionless_dirs = true;
    data.SetSortMode(sorting);
    CHECK(data.EntryAtSortPosition(0).Filename() == "Alpha.2");
    CHECK(data.EntryAtSortPosition(1).Filename() == "Bravo.1");
    CHECK(data.EntryAtSortPosition(2).Filename() == "Charlie.3");

    sorting = data::SortMode{};
    sorting.sort = data::SortMode::SortByExtRev;
    data.SetSortMode(sorting);
    CHECK(data.EntryAtSortPosition(0).Filename() == "Charlie.3");
    CHECK(data.EntryAtSortPosition(1).Filename() == "Alpha.2");
    CHECK(data.EntryAtSortPosition(2).Filename() == "Bravo.1");

    sorting.extensionless_dirs = true;
    data.SetSortMode(sorting);
    CHECK(data.EntryAtSortPosition(0).Filename() == "Charlie.3");
    CHECK(data.EntryAtSortPosition(1).Filename() == "Bravo.1");
    CHECK(data.EntryAtSortPosition(2).Filename() == "Alpha.2");
}

TEST_CASE(PREFIX "SetCalculatedSizeForDirectory")
{
    const std::vector<std::tuple<std::string, bool>> entries = {{{"Alpha", true}, {"Bravo", true}, {"Charlie", true}}};
    auto listing = ProduceDummyListing(entries);

    data::Model data;
    data.Load(listing, data::Model::PanelType::Directory);

    auto sorting = data::SortMode{};
    sorting.sort = data::SortMode::SortBySize;
    data.SetSortMode(sorting);
    CHECK(data.EntryAtSortPosition(0).Filename() == "Alpha");
    CHECK(data.EntryAtSortPosition(1).Filename() == "Bravo");
    CHECK(data.EntryAtSortPosition(2).Filename() == "Charlie");
    CHECK(data.VolatileDataAtRawPosition(0).size == ItemVolatileData::invalid_size);
    CHECK(data.VolatileDataAtRawPosition(1).size == ItemVolatileData::invalid_size);
    CHECK(data.VolatileDataAtRawPosition(2).size == ItemVolatileData::invalid_size);

    SECTION("Valid")
    {
        CHECK(data.SetCalculatedSizeForDirectory("Bravo", "/", 10));
        CHECK(data.VolatileDataAtRawPosition(1).size == 10);
        CHECK(data.EntryAtSortPosition(0).Filename() == "Alpha");
        CHECK(data.EntryAtSortPosition(1).Filename() == "Charlie");
        CHECK(data.EntryAtSortPosition(2).Filename() == "Bravo");

        CHECK(data.SetCalculatedSizeForDirectory("Alpha", "/", 20));
        CHECK(data.VolatileDataAtRawPosition(0).size == 20);
        CHECK(data.EntryAtSortPosition(0).Filename() == "Charlie");
        CHECK(data.EntryAtSortPosition(1).Filename() == "Alpha");
        CHECK(data.EntryAtSortPosition(2).Filename() == "Bravo");

        CHECK(data.SetCalculatedSizeForDirectory("Charlie", "/", 30));
        CHECK(data.VolatileDataAtRawPosition(2).size == 30);
        CHECK(data.EntryAtSortPosition(0).Filename() == "Charlie");
        CHECK(data.EntryAtSortPosition(1).Filename() == "Alpha");
        CHECK(data.EntryAtSortPosition(2).Filename() == "Bravo");
    }
    SECTION("Invalid ")
    {
        CHECK(data.SetCalculatedSizeForDirectory("Blah-Blah", "/", 10) == false);
        CHECK(data.SetCalculatedSizeForDirectory({}, "/", 10) == false);
        CHECK(data.SetCalculatedSizeForDirectory("Alpha", {}, 10) == false);
        CHECK(data.SetCalculatedSizeForDirectory("Charlie", "/", ItemVolatileData::invalid_size) == false);
    }
}

TEST_CASE(PREFIX "SetCalculatedSizesForDirectories")
{
    const std::vector<std::tuple<std::string, bool>> entries = {{{"Alpha", true}, {"Bravo", true}, {"Charlie", true}}};
    auto listing = ProduceDummyListing(entries);

    data::Model data;
    data.Load(listing, data::Model::PanelType::Directory);

    auto sorting = data::SortMode{};
    sorting.sort = data::SortMode::SortBySize;
    data.SetSortMode(sorting);
    CHECK(data.EntryAtSortPosition(0).Filename() == "Alpha");
    CHECK(data.EntryAtSortPosition(1).Filename() == "Bravo");
    CHECK(data.EntryAtSortPosition(2).Filename() == "Charlie");
    CHECK(data.VolatileDataAtRawPosition(0).size == ItemVolatileData::invalid_size);
    CHECK(data.VolatileDataAtRawPosition(1).size == ItemVolatileData::invalid_size);
    CHECK(data.VolatileDataAtRawPosition(2).size == ItemVolatileData::invalid_size);

    SECTION("Empty")
    {
        CHECK(data.SetCalculatedSizesForDirectories({}, {}, {}) == 0);
        CHECK(data.EntryAtSortPosition(0).Filename() == "Alpha");
        CHECK(data.EntryAtSortPosition(1).Filename() == "Bravo");
        CHECK(data.EntryAtSortPosition(2).Filename() == "Charlie");
        CHECK(data.VolatileDataAtRawPosition(0).size == ItemVolatileData::invalid_size);
        CHECK(data.VolatileDataAtRawPosition(1).size == ItemVolatileData::invalid_size);
        CHECK(data.VolatileDataAtRawPosition(2).size == ItemVolatileData::invalid_size);
    }
    SECTION("Valid")
    {
        SECTION("1 element")
        {
            const std::string_view filenames[1] = {"Alpha"};
            const std::string_view directories[1] = {"/"};
            const uint64_t sizes[1] = {10};
            CHECK(data.SetCalculatedSizesForDirectories(filenames, directories, sizes) == 1);
            CHECK(data.EntryAtSortPosition(0).Filename() == "Bravo");
            CHECK(data.EntryAtSortPosition(1).Filename() == "Charlie");
            CHECK(data.EntryAtSortPosition(2).Filename() == "Alpha");
            CHECK(data.VolatileDataAtRawPosition(0).size == 10);
            CHECK(data.VolatileDataAtRawPosition(1).size == ItemVolatileData::invalid_size);
            CHECK(data.VolatileDataAtRawPosition(2).size == ItemVolatileData::invalid_size);
        }
        SECTION("3 elements")
        {
            const std::string_view filenames[] = {"Alpha", "Bravo", "Charlie"};
            const std::string_view directories[] = {"/", "/", "/"};
            const uint64_t sizes[] = {10, 20, 30};
            CHECK(data.SetCalculatedSizesForDirectories(filenames, directories, sizes) == 3);
            CHECK(data.EntryAtSortPosition(0).Filename() == "Charlie");
            CHECK(data.EntryAtSortPosition(1).Filename() == "Bravo");
            CHECK(data.EntryAtSortPosition(2).Filename() == "Alpha");
            CHECK(data.VolatileDataAtRawPosition(0).size == 10);
            CHECK(data.VolatileDataAtRawPosition(1).size == 20);
            CHECK(data.VolatileDataAtRawPosition(2).size == 30);
        }
    }
    SECTION("Invalid")
    {
        SECTION("Wrong elements number")
        {
            const std::string_view filenames[] = {"Alpha", "Bravo"};
            const std::string_view directories[] = {"/", "/", "/"};
            const uint64_t sizes[] = {10, 20, 30};
            CHECK(data.SetCalculatedSizesForDirectories(filenames, directories, sizes) == 0);
            CHECK(data.EntryAtSortPosition(0).Filename() == "Alpha");
            CHECK(data.EntryAtSortPosition(1).Filename() == "Bravo");
            CHECK(data.EntryAtSortPosition(2).Filename() == "Charlie");
            CHECK(data.VolatileDataAtRawPosition(0).size == ItemVolatileData::invalid_size);
            CHECK(data.VolatileDataAtRawPosition(1).size == ItemVolatileData::invalid_size);
            CHECK(data.VolatileDataAtRawPosition(2).size == ItemVolatileData::invalid_size);
        }
        SECTION("Non-existing elements")
        {
            const std::string_view filenames[] = {"Alpha", "Bravo", "Charlie1"};
            const std::string_view directories[] = {"/", "/", "/"};
            const uint64_t sizes[] = {10, 20, 30};
            CHECK(data.SetCalculatedSizesForDirectories(filenames, directories, sizes) == 2);
            CHECK(data.EntryAtSortPosition(0).Filename() == "Charlie");
            CHECK(data.EntryAtSortPosition(1).Filename() == "Bravo");
            CHECK(data.EntryAtSortPosition(2).Filename() == "Alpha");
            CHECK(data.VolatileDataAtRawPosition(0).size == 10);
            CHECK(data.VolatileDataAtRawPosition(1).size == 20);
            CHECK(data.VolatileDataAtRawPosition(2).size == ItemVolatileData::invalid_size);
        }
    }
    SECTION("Valid, raw indices")
    {
        SECTION("1 element")
        {
            const unsigned indices[1] = {0};
            const uint64_t sizes[1] = {10};
            CHECK(data.SetCalculatedSizesForDirectories(indices, sizes) == 1);
            CHECK(data.EntryAtSortPosition(0).Filename() == "Bravo");
            CHECK(data.EntryAtSortPosition(1).Filename() == "Charlie");
            CHECK(data.EntryAtSortPosition(2).Filename() == "Alpha");
            CHECK(data.VolatileDataAtRawPosition(0).size == 10);
            CHECK(data.VolatileDataAtRawPosition(1).size == ItemVolatileData::invalid_size);
            CHECK(data.VolatileDataAtRawPosition(2).size == ItemVolatileData::invalid_size);
        }
        SECTION("3 elements")
        {
            const unsigned indices[3] = {0, 1, 2};
            const uint64_t sizes[] = {10, 20, 30};
            CHECK(data.SetCalculatedSizesForDirectories(indices, sizes) == 3);
            CHECK(data.EntryAtSortPosition(0).Filename() == "Charlie");
            CHECK(data.EntryAtSortPosition(1).Filename() == "Bravo");
            CHECK(data.EntryAtSortPosition(2).Filename() == "Alpha");
            CHECK(data.VolatileDataAtRawPosition(0).size == 10);
            CHECK(data.VolatileDataAtRawPosition(1).size == 20);
            CHECK(data.VolatileDataAtRawPosition(2).size == 30);
        }
    }
}

TEST_CASE(PREFIX "ReLoad a temporary listing")
{
    const VFSListingPtr l1 = ProduceNonUniformDummyListing({{"/D1/", "meow.txt", 10}, {"/D2/", "bark.txt", 20}});
    CHECK(l1->IsUniform() == false);

    data::Model data;
    data.Load(l1, data::Model::PanelType::Temporary);
    data.CustomFlagsSelectSorted(0, true);
    data.CustomFlagsSelectSorted(1, true);

    SECTION("Same items, Different order, updated size")
    {
        const VFSListingPtr l2 = ProduceNonUniformDummyListing({{"/D2/", "bark.txt", 21}, {"/D1/", "meow.txt", 11}});
        data.ReLoad(l2);
        CHECK(data.EntryAtSortPosition(data.SortedIndexForName("bark.txt")).Size() == 21);
        CHECK(data.EntryAtSortPosition(data.SortedIndexForName("bark.txt")).Directory() == "/D2/");
        CHECK(data.VolatileDataAtSortPosition(data.SortedIndexForName("bark.txt")).is_selected());
        CHECK(data.EntryAtSortPosition(data.SortedIndexForName("meow.txt")).Size() == 11);
        CHECK(data.EntryAtSortPosition(data.SortedIndexForName("meow.txt")).Directory() == "/D1/");
        CHECK(data.VolatileDataAtSortPosition(data.SortedIndexForName("meow.txt")).is_selected());
    }
#if 0
    SECTION("One added")
    {
        // currently can only remove items
        VFSListingPtr l2 = ProduceNonUniformDummyListing(
            {{"/D2/", "bark.txt", 21}, {"/D1/", "meow.txt", 11}, {"/D1/", "hiss.txt", 55}});
        data.ReLoad(l2);
        CHECK(data.EntryAtSortPosition(data.SortedIndexForName("bark.txt")).Size() == 21);
        CHECK(data.VolatileDataAtSortPosition(data.SortedIndexForName("bark.txt")).is_selected());
        CHECK(data.EntryAtSortPosition(data.SortedIndexForName("meow.txt")).Size() == 11);
        CHECK(data.VolatileDataAtSortPosition(data.SortedIndexForName("meow.txt")).is_selected());
        CHECK(data.EntryAtSortPosition(data.SortedIndexForName("hiss.txt")).Size() == 55);
        CHECK(data.VolatileDataAtSortPosition(data.SortedIndexForName("hiss")).is_selected() == false);
    }
#endif
    SECTION("One removed, updated size")
    {
        const VFSListingPtr l2 = ProduceNonUniformDummyListing({{"/D2/", "bark.txt", 21}});
        data.ReLoad(l2);
        CHECK(data.EntryAtSortPosition(data.SortedIndexForName("bark.txt")).Size() == 21);
        CHECK(data.EntryAtSortPosition(data.SortedIndexForName("bark.txt")).Directory() == "/D2/");
        CHECK(data.VolatileDataAtSortPosition(data.SortedIndexForName("bark.txt")).is_selected());
        CHECK(data.SortedIndexForName("meow.txt") == -1);
    }
    SECTION("Both removed")
    {
        const VFSListingPtr l2 = ProduceNonUniformDummyListing({});
        data.ReLoad(l2);
        CHECK(data.SortedIndexForName("bark.txt") == -1);
        CHECK(data.SortedIndexForName("meow.txt") == -1);
    }
}
