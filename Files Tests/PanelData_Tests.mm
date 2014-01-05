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


@end
