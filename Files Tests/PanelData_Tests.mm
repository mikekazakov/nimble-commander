//
//  PanelData_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 05.01.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "tests_common.h"
#include "VFS.h"
#include "PanelData.h"

static shared_ptr<VFSFlexibleListing> ProduceDummyListing( const vector<string> &_filenames )
{
    VFSFlexibleListingInput l;
    
    l.directories.reset( variable_container<>::type::common );
    l.directories[0] = "/";

    l.hosts.reset( variable_container<>::type::common );
    l.hosts[0] = VFSHost::DummyHost();
    
    for(auto &i: _filenames) {
        l.filenames.emplace_back(i);
        l.unix_modes.emplace_back(0);
        l.unix_types.emplace_back(0);
    }
    
    return VFSFlexibleListing::Build(move(l));
}


static shared_ptr<VFSFlexibleListing> ProduceDummyListing( const vector<NSString*> &_filenames )
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
    auto listing = ProduceDummyListing({@"..",
                                        @"some filename",
                                        @"another filename",
                                        @"even written with какие-то буквы"});
    
    PanelData data;
    data.Load(listing);
    
    // testing raw C sorting facility
    for(int i = 0; i < listing->Count(); ++i)
        XCTAssert(data.RawIndexForName( listing->Filename(i).c_str() ) == i);
    
    // testing basic sorting (direct by filename)
    auto sorting = data.SortMode();
    sorting.sort = PanelSortMode::SortByName;
    data.SetSortMode(sorting);
    
    XCTAssert(data.SortedIndexForName(listing->Filename(0).c_str()) == 0);
    XCTAssert(data.SortedIndexForName(listing->Filename(2).c_str()) == 1);
    XCTAssert(data.SortedIndexForName(listing->Filename(3).c_str()) == 2);
    XCTAssert(data.SortedIndexForName(listing->Filename(1).c_str()) == 3);
}

- (void)testSortingWithCases
{
    auto listing = ProduceDummyListing({@"аааа",
                                        @"бббб",
                                        @"АААА",
                                        @"ББББ"});

    PanelData data;
    auto sorting = data.SortMode();
    sorting.sort = PanelSortMode::SortByName;
    sorting.case_sens = false;
    data.SetSortMode(sorting);
    data.Load(move(listing));
    
    XCTAssert(data.SortedIndexForName(listing->Item(0).Name()) == 0);
    XCTAssert(data.SortedIndexForName(listing->Item(2).Name()) == 1);
    XCTAssert(data.SortedIndexForName(listing->Item(1).Name()) == 2);
    XCTAssert(data.SortedIndexForName(listing->Item(3).Name()) == 3);
    
    sorting.case_sens = true;
    data.SetSortMode(sorting);
    XCTAssert(data.SortedIndexForName(listing->Item(2).Name()) == 0);
    XCTAssert(data.SortedIndexForName(listing->Item(3).Name()) == 1);
    XCTAssert(data.SortedIndexForName(listing->Item(0).Name()) == 2);
    XCTAssert(data.SortedIndexForName(listing->Item(1).Name()) == 3);
}

- (void)testHardFiltering
{
    // just my home dir below
    auto listing = ProduceDummyListing({@"..",
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
    });
    
    auto empty_listing = VFSFlexibleListing::EmptyListing();
    
    auto almost_empty_listing = ProduceDummyListing({@"какой-то файл"});
    
    PanelData data;
    PanelSortMode sorting = data.SortMode();
    sorting.sort = PanelSortMode::SortByName;
    data.SetSortMode(sorting);
    
    PanelDataHardFiltering filtering = data.HardFiltering();
    filtering.show_hidden = true;
    data.SetHardFiltering(filtering);
    
    data.Load(listing);
    XCTAssert(data.SortedIndexForName("..") == 0);
    XCTAssert(data.SortedIndexForName(".Trash") >= 0);
    XCTAssert(data.SortedIndexForName("Games") >= 0);
    
    filtering.show_hidden = false;
    data.SetHardFiltering(filtering);
    XCTAssert(data.SortedIndexForName("..") == 0);
    XCTAssert(data.SortedIndexForName(".Trash") < 0);
    XCTAssert(data.SortedIndexForName("Games") >= 0);

    filtering.text.type = PanelDataTextFiltering::Anywhere;
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
    data.Load(empty_listing);
    XCTAssert(data.SortedIndexForName("..") < 0);

    // now test what will happen on almost empty listing (will became empty after filtering)
    data.Load(almost_empty_listing);
    XCTAssert(data.SortedIndexForName("..") < 0);
    
    // now more comples situations
    filtering.text.text = @"IC";
    data.SetHardFiltering(filtering);
    auto count = listing->Count();
    data.Load(listing);
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
    
    filtering.text.type = PanelDataTextFiltering::Beginning;
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
    filtering.text.type = PanelDataTextFiltering::Beginning;
    filtering.text.text = @"";
    filtering.show_hidden = true;
    data.SetHardFiltering(filtering);
    XCTAssert(data.SortedIndexForName("..") == 0);
    XCTAssert(data.SortedDirectoryEntries().size() == count);
}

@end
