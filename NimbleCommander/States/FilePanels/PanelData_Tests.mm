// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include <sys/dirent.h>
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include <VFS/VFSListingInput.h>
#include <NimbleCommander/States/FilePanels/PanelData.h>
#include <NimbleCommander/States/FilePanels/PanelDataSelection.h>

using namespace nc;
using namespace nc::panel;

static shared_ptr<VFSListing> ProduceDummyListing( const vector<string> &_filenames )
{
    vfs::ListingInput l;
    
    l.directories.reset( variable_container<>::type::common );
    l.directories[0] = "/";

    l.hosts.reset( variable_container<>::type::common );
    l.hosts[0] = VFSHost::DummyHost();
    
    for(auto &i: _filenames) {
        l.filenames.emplace_back(i);
        l.unix_modes.emplace_back(0);
        l.unix_types.emplace_back(0);
    }
    
    return VFSListing::Build(move(l));
}

// filename, is_directory
static shared_ptr<VFSListing> ProduceDummyListing( const vector<tuple<string,bool>> &_entries )
{
    vfs::ListingInput l;
    
    l.directories.reset( variable_container<>::type::common );
    l.directories[0] = "/";

    l.hosts.reset( variable_container<>::type::common );
    l.hosts[0] = VFSHost::DummyHost();
    
    for(auto &i: _entries) {
        const auto &filename = get<0>(i);
        const auto is_directory = get<1>(i);
        l.filenames.emplace_back(filename);
        l.unix_modes.emplace_back(is_directory ?
                                  (S_IRUSR | S_IWUSR | S_IFDIR) :
                                  (S_IRUSR | S_IWUSR | S_IFREG));
        l.unix_types.emplace_back(is_directory ? DT_DIR : DT_REG);
    }
    return VFSListing::Build(move(l));
}


static shared_ptr<VFSListing> ProduceDummyListing( const vector<NSString*> &_filenames )
{
    vector<string> t;
    for( auto &i: _filenames )
        t.emplace_back( i.fileSystemRepresentation );
    
    return ProduceDummyListing(t);
}

@interface PanelData_Tests : XCTestCase

@end


@implementation PanelData_Tests

- (void)testBasic
{
    NSString* strings[] = { @"..",
                            @"some filename",
                            @"another filename",
                            @"even written with какие-то буквы" };
    auto listing = ProduceDummyListing(vector<NSString*>(begin(strings), end(strings)));
    
    data::Model data;
    data.Load(listing, data::Model::PanelType::Directory);
    
    // testing raw C sorting facility
    for(int i = 0; i < listing->Count(); ++i)
        XCTAssert(data.RawIndexForName( listing->Filename(i).c_str() ) == i);
    
    // testing basic sorting (direct by filename)
    auto sorting = data.SortMode();
    sorting.sort = data::SortMode::SortByName;
    data.SetSortMode(sorting);
    
    XCTAssert(data.SortedIndexForName(listing->Filename(0).c_str()) == 0);
    XCTAssert(data.SortedIndexForName(listing->Filename(2).c_str()) == 1);
    XCTAssert(data.SortedIndexForName(listing->Filename(3).c_str()) == 2);
    XCTAssert(data.SortedIndexForName(listing->Filename(1).c_str()) == 3);
}

- (void)testSortingWithCases
{
    NSString* strings[] = { @"аааа",
                            @"бббб",
                            @"АААА",
                            @"ББББ" };
    auto listing = ProduceDummyListing(vector<NSString*>(begin(strings), end(strings)));

    data::Model data;
    auto sorting = data.SortMode();
    sorting.sort = data::SortMode::SortByName;
    sorting.case_sens = false;
    data.SetSortMode(sorting);
    data.Load(move(listing), data::Model::PanelType::Directory);
    
    XCTAssert(data.SortedIndexForName(listing->Item(0).FilenameC()) == 0);
    XCTAssert(data.SortedIndexForName(listing->Item(2).FilenameC()) == 1);
    XCTAssert(data.SortedIndexForName(listing->Item(1).FilenameC()) == 2);
    XCTAssert(data.SortedIndexForName(listing->Item(3).FilenameC()) == 3);
    
    sorting.case_sens = true;
    data.SetSortMode(sorting);
    XCTAssert(data.SortedIndexForName(listing->Item(2).FilenameC()) == 0);
    XCTAssert(data.SortedIndexForName(listing->Item(3).FilenameC()) == 1);
    XCTAssert(data.SortedIndexForName(listing->Item(0).FilenameC()) == 2);
    XCTAssert(data.SortedIndexForName(listing->Item(1).FilenameC()) == 3);
}

- (void)testHardFiltering
{
    // just my home dir below
    NSString* strings[] = {@"..",
        @".cache",
        @"АААА",
        @"ББББ",
        @".config",
        @".cups",
        @".dropbox",
        @".dvdcss",
        @".local",
        @".mplayer",
        @".ssh",
        @".subversion",
        @".Trash",
        @"Applications",
        @"Another app",
        @"Another app number two",
        @"Applications (Parallels)",
        @"что-то на русском языке",
        @"ЕЩЕ РУССКИЙ ЯЗЫК",
        @"Desktop",
        @"Documents",
        @"Downloads",
        @"Dropbox",
        @"Games",
        @"Library",
        @"Movies",
        @"Music",
        @"Pictures",
        @"Public"
    };
    auto listing = ProduceDummyListing(vector<NSString*>(begin(strings), end(strings)));
    
    auto empty_listing = VFSListing::EmptyListing();
    
    auto almost_empty_listing = ProduceDummyListing(vector<NSString*>(1, @"какой-то файл"));
    
    data::Model data;
    auto sorting = data.SortMode();
    sorting.sort = data::SortMode::SortByName;
    data.SetSortMode(sorting);
    
    
    auto filtering = data.HardFiltering();
    filtering.show_hidden = true;
    data.SetHardFiltering(filtering);
    
    data.Load(listing, data::Model::PanelType::Directory);
    XCTAssert(data.SortedIndexForName("..") == 0);
    XCTAssert(data.SortedIndexForName(".Trash") >= 0);
    XCTAssert(data.SortedIndexForName("Games") >= 0);
    
    filtering.show_hidden = false;
    data.SetHardFiltering(filtering);
    XCTAssert(data.SortedIndexForName("..") == 0);
    XCTAssert(data.SortedIndexForName(".Trash") < 0);
    XCTAssert(data.SortedIndexForName("Games") >= 0);

    filtering.text.type = data::TextualFilter::Anywhere;
    filtering.text.text = @"D";
    data.SetHardFiltering(filtering);
    
    XCTAssert(data.SortedIndexForName("..") == 0);
    XCTAssert(data.SortedIndexForName(".Trash") < 0);
    XCTAssert(data.SortedIndexForName("Games") < 0);
    XCTAssert(data.SortedIndexForName("Desktop") >= 0);
 
    filtering.text.text = @"a very long-long filtering string that will never leave any file even с другим языком внутри";
    data.SetHardFiltering(filtering);
    XCTAssert(data.SortedIndexForName("..") == 0);
    XCTAssert(data.SortedIndexForName("Desktop") < 0);
    XCTAssert(data.SortedDirectoryEntries().size() == 1);
    
    // now test what will happen on empty listing
    data.Load(empty_listing, data::Model::PanelType::Directory);
    XCTAssert(data.SortedIndexForName("..") < 0);

    // now test what will happen on almost empty listing (will became empty after filtering)
    data.Load(almost_empty_listing, data::Model::PanelType::Directory);
    XCTAssert(data.SortedIndexForName("..") < 0);
    
    // now more comples situations
    filtering.text.text = @"IC";
    data.SetHardFiltering(filtering);
    auto count = listing->Count();
    data.Load(listing, data::Model::PanelType::Directory);
    XCTAssert(data.SortedIndexForName("..") == 0);
    XCTAssert(data.SortedIndexForName("Music") >= 0);
    XCTAssert(data.SortedIndexForName("Pictures") >= 0);
    XCTAssert(data.SortedIndexForName("Public") >= 0);
    XCTAssert(data.SortedDirectoryEntries().size() == 6);
    
    filtering.text.text = @"русск";
    data.SetHardFiltering(filtering);
    XCTAssert(data.SortedIndexForName("..") == 0);
    XCTAssert(data.SortedIndexForName("Pictures") < 0);
    XCTAssert(data.SortedIndexForName("Public") < 0);
    XCTAssert(data.SortedIndexForName(@"что-то на русском языке".fileSystemRepresentation) >= 0);
    XCTAssert(data.SortedIndexForName(@"ЕЩЕ РУССКИЙ ЯЗЫК".fileSystemRepresentation) >= 0);
    
    filtering.text.type = data::TextualFilter::Beginning;
    filtering.text.text = @"APP";
    data.SetHardFiltering(filtering);
    XCTAssert(data.SortedIndexForName("..") == 0);
    XCTAssert(data.SortedIndexForName("Pictures") < 0);
    XCTAssert(data.SortedIndexForName("Public") < 0);
    XCTAssert(data.SortedIndexForName("Applications") > 0);
    XCTAssert(data.SortedIndexForName("Applications (Parallels)") > 0);
    XCTAssert(data.SortedIndexForName("Another app") < 0);
    XCTAssert(data.SortedIndexForName("Another app number two") < 0);

    // test buggy filtering with @"" string
    filtering.text.type = data::TextualFilter::Beginning;
    filtering.text.text = @"";
    filtering.show_hidden = true;
    data.SetHardFiltering(filtering);
    XCTAssert(data.SortedIndexForName("..") == 0);
    XCTAssert(data.SortedDirectoryEntries().size() == count);
}

//  unsigned CustomFlagsSelectAllSortedByExtension(const string &_extension, bool _select, bool _ignore_dirs);


- (void)testSelectionWithExtension
{
    VFSHostPtr host = VFSNativeHost::SharedHost();
    VFSListingPtr listing;
    data::Model data;
    data::SelectionBuilder selector{data, true};
    data::SelectionBuilder selector_w_dirs{data, false};
    
    host->FetchDirectoryListing("/bin/", listing, 0);
    data.Load(listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted( selector.SelectionByExtension("", true) );
    XCTAssert( data.Stats().selected_entries_amount >= 30 );
    
    host->FetchDirectoryListing("/usr/share/man/man1", listing, 0);
    data.Load(listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted( selector.SelectionByExtension("1", true) );
    XCTAssert( data.Stats().selected_entries_amount >= 1000 );
    
    host->FetchDirectoryListing("/System/Library/CoreServices", listing, 0);

    data.Load(listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted( selector.SelectionByExtension("app", true) );
    XCTAssert( data.Stats().selected_entries_amount == 0 );

    data.Load(listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted( selector_w_dirs.SelectionByExtension("app", true) );
    XCTAssert( data.Stats().selected_entries_amount >= 30 );

    data.Load(listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted( selector_w_dirs.SelectionByExtension("App", true) );
    XCTAssert( data.Stats().selected_entries_amount >= 30 );
    
    data.Load(listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted( selector_w_dirs.SelectionByExtension("ApP", true) );
    XCTAssert( data.Stats().selected_entries_amount >= 30 );

    data.Load(listing, data::Model::PanelType::Directory);
    data.CustomFlagsSelectSorted( selector_w_dirs.SelectionByExtension("APP", true) );
    XCTAssert( data.Stats().selected_entries_amount >= 30 );
}

- (void) testDirectorySorting
{
    const vector<tuple<string,bool>> entries = {{
        {"Alpha.2", true},
        {"Bravo.1", true},
        {"Charlie.3", true}
    }};
    auto listing = ProduceDummyListing(entries);

    data::Model data;
    data.Load(listing, data::Model::PanelType::Directory);
    
    data::SortMode sorting;
    sorting.sort = data::SortMode::SortByExt;
    data.SetSortMode(sorting);
    XCTAssert( data.EntryAtSortPosition(0).Filename() == "Bravo.1" );
    XCTAssert( data.EntryAtSortPosition(1).Filename() == "Alpha.2" );
    XCTAssert( data.EntryAtSortPosition(2).Filename() == "Charlie.3" );
    
    sorting.extensionless_dirs = true;
    data.SetSortMode(sorting);
    XCTAssert( data.EntryAtSortPosition(0).Filename() == "Alpha.2" );
    XCTAssert( data.EntryAtSortPosition(1).Filename() == "Bravo.1" );
    XCTAssert( data.EntryAtSortPosition(2).Filename() == "Charlie.3" );
    
    sorting = data::SortMode{};
    sorting.sort = data::SortMode::SortByExtRev;
    data.SetSortMode(sorting);
    XCTAssert( data.EntryAtSortPosition(0).Filename() == "Charlie.3" );
    XCTAssert( data.EntryAtSortPosition(1).Filename() == "Alpha.2" );
    XCTAssert( data.EntryAtSortPosition(2).Filename() == "Bravo.1" );

    sorting.extensionless_dirs = true;
    data.SetSortMode(sorting);
    XCTAssert( data.EntryAtSortPosition(0).Filename() == "Charlie.3" );
    XCTAssert( data.EntryAtSortPosition(1).Filename() == "Bravo.1" );
    XCTAssert( data.EntryAtSortPosition(2).Filename() == "Alpha.2" );
}

@end
