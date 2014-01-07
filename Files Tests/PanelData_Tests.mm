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

struct DummyVFSListingTestItem : public VFSListingItem
{
    DummyVFSListingTestItem(NSString *_name): name(_name) { }
    
    NSString *name;

    virtual const char     *Name()      const override { return [name UTF8String]; }
    virtual size_t          NameLen()   const override { return strlen([name UTF8String]); }
    virtual CFStringRef     CFName()    const override { return (__bridge CFStringRef)name; }
};

struct DummyVFSTestListing : public VFSListing
{
    DummyVFSTestListing(): VFSListing("/", 0) { }
    
    vector<DummyVFSListingTestItem> items;
    
    virtual VFSListingItem& At(size_t _position) override { return items[_position]; }
    virtual const VFSListingItem& At(size_t _position) const override { return items[_position]; }
    virtual int Count() const override {return (int)items.size(); };
};


@interface PanelData_Tests : XCTestCase

@end


@implementation PanelData_Tests

- (void)testBasic
{
    auto listing = make_shared<DummyVFSTestListing>();
    listing->items.emplace_back(@"..");
    listing->items.emplace_back(@"some filename");
    listing->items.emplace_back(@"another filename");
    listing->items.emplace_back(@"even written with какие-то буквы");
    
    PanelData data;
    data.Load(listing);
    
    // testing raw C sorting facility
    for(int i = 0; i < listing->items.size(); ++i)
        XCTAssert(data.RawIndexForName(listing->items[i].Name()) == i);
    
    // testing basic sorting (direct by filename)
    auto sorting = data.GetCustomSortMode();
    sorting.sort = PanelSortMode::SortByName;
    data.SetCustomSortMode(sorting);
    
    XCTAssert(data.SortedIndexForName(listing->items[0].Name()) == 0);
    XCTAssert(data.SortedIndexForName(listing->items[2].Name()) == 1);
    XCTAssert(data.SortedIndexForName(listing->items[3].Name()) == 2);
    XCTAssert(data.SortedIndexForName(listing->items[1].Name()) == 3);
}

- (void)testSortingWithCases
{
    auto listing = make_shared<DummyVFSTestListing>();
    listing->items.emplace_back(@"аааа");
    listing->items.emplace_back(@"бббб");
    listing->items.emplace_back(@"АААА");
    listing->items.emplace_back(@"ББББ");

    PanelData data;
    auto sorting = data.GetCustomSortMode();
    sorting.sort = PanelSortMode::SortByName;
    sorting.case_sens = false;
    data.SetCustomSortMode(sorting);
    data.Load(listing);
    
    XCTAssert(data.SortedIndexForName(listing->items[0].Name()) == 0);
    XCTAssert(data.SortedIndexForName(listing->items[2].Name()) == 1);
    XCTAssert(data.SortedIndexForName(listing->items[1].Name()) == 2);
    XCTAssert(data.SortedIndexForName(listing->items[3].Name()) == 3);
    
    sorting.case_sens = true;
    data.SetCustomSortMode(sorting);
    XCTAssert(data.SortedIndexForName(listing->items[2].Name()) == 0);
    XCTAssert(data.SortedIndexForName(listing->items[3].Name()) == 1);
    XCTAssert(data.SortedIndexForName(listing->items[0].Name()) == 2);
    XCTAssert(data.SortedIndexForName(listing->items[1].Name()) == 3);
}

- (void)testHardFiltering
{
    auto listing = make_shared<DummyVFSTestListing>();
    // just my home dir below
    listing->items.emplace_back(@"..");
    listing->items.emplace_back(@".cache");
    listing->items.emplace_back(@".config");
    listing->items.emplace_back(@".cups");
    listing->items.emplace_back(@".dropbox");
    listing->items.emplace_back(@".dvdcss");
    listing->items.emplace_back(@".local");
    listing->items.emplace_back(@".mplayer");
    listing->items.emplace_back(@".ssh");
    listing->items.emplace_back(@".subversion");
    listing->items.emplace_back(@".Trash");
    listing->items.emplace_back(@"Applications");
    listing->items.emplace_back(@"Applications (Parallels)");
    listing->items.emplace_back(@"что-то на русском языке");
    listing->items.emplace_back(@"ЕЩЕ РУССКИЙ ЯЗЫК");
    listing->items.emplace_back(@"Desktop");
    listing->items.emplace_back(@"Documents");
    listing->items.emplace_back(@"Downloads");
    listing->items.emplace_back(@"Dropbox");
    listing->items.emplace_back(@"Games");
    listing->items.emplace_back(@"Library");
    listing->items.emplace_back(@"Movies");
    listing->items.emplace_back(@"Music");
    listing->items.emplace_back(@"Pictures");
    listing->items.emplace_back(@"Public");

    auto empty_listing = make_shared<DummyVFSTestListing>();
    
    auto almost_empty_listing = make_shared<DummyVFSTestListing>();
    almost_empty_listing->items.emplace_back(@"какой-то файл");
    
    PanelData data;
    PanelSortMode sorting = data.GetCustomSortMode();
    sorting.sort = PanelSortMode::SortByName;
    data.SetCustomSortMode(sorting);
    
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
    XCTAssert(data.SortedIndexForName(@"что-то на русском языке".UTF8String) >= 0);
    XCTAssert(data.SortedIndexForName(@"ЕЩЕ РУССКИЙ ЯЗЫК".UTF8String) >= 0);
    
}



@end
