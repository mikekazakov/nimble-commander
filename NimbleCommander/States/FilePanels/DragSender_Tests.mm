// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include "DragSender.h"
#include <VFS/VFS.h>
#include <VFS/VFSListingInput.h>
#include <NimbleCommander/States/FilePanels/PanelData.h>
#include <NimbleCommander/States/FilePanels/PanelDataSelection.h>

using namespace nc;
using namespace nc::base;
using namespace nc::panel;

@interface DragSender_Tests : XCTestCase

@end

static std::shared_ptr<VFSListing> ProduceDummyListing( const std::vector<std::string> &_filenames )
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
    
    return VFSListing::Build(std::move(l));
}

@implementation DragSender_Tests

- (void)testComposeItemsForDragging
{
    { // empty
        data::Model data;
        data.Load(ProduceDummyListing({}), data::Model::PanelType::Directory);
        auto items = DragSender::Impl::ComposeItemsForDragging(-1, data);
        XCTAssert( items.empty() ); 
    }
    { // attempting to drag ".."
        data::Model data;
        data.Load(ProduceDummyListing({"..", "a"}), data::Model::PanelType::Directory);
        auto items = DragSender::Impl::ComposeItemsForDragging(0, data);
        XCTAssert( items.empty() ); 
    }
    { // dragging a single non-selected item
        data::Model data;
        data.Load(ProduceDummyListing({"..", "a", "b"}), data::Model::PanelType::Directory);
        auto items1 = DragSender::Impl::ComposeItemsForDragging(1, data);
        XCTAssert( items1.size() == 1 );
        XCTAssert( items1[0].Filename() == "a" );
        auto items2 = DragSender::Impl::ComposeItemsForDragging(2, data);
        XCTAssert( items2.size() == 1 );
        XCTAssert( items2[0].Filename() == "b" );
    }
    { // dragging two selected items
        data::Model data;
        data.Load(ProduceDummyListing({"..", "a", "b"}), data::Model::PanelType::Directory);
        data.CustomFlagsSelectSorted( data::SelectionBuilder{data}.SelectionByMask("*") );
        auto items1 = DragSender::Impl::ComposeItemsForDragging(1, data);
        XCTAssert( items1.size() == 2 );
        XCTAssert( items1[0].Filename() == "a" );
        XCTAssert( items1[1].Filename() == "b" ); 
        auto items2 = DragSender::Impl::ComposeItemsForDragging(2, data);
        XCTAssert( items2.size() == 2 );
        XCTAssert( items2[0].Filename() == "a" );
        XCTAssert( items2[1].Filename() == "b" ); 
    }
    { // dragging two selected items of three
        data::Model data;
        data.Load(ProduceDummyListing({"..", "a", "b", "c"}), data::Model::PanelType::Directory);
        data.CustomFlagsSelectSorted( 1, true );
        data.CustomFlagsSelectSorted( 2, true );
        auto items1 = DragSender::Impl::ComposeItemsForDragging(1, data);
        XCTAssert( items1.size() == 2 );
        XCTAssert( items1[0].Filename() == "a" );
        XCTAssert( items1[1].Filename() == "b" );
        
         auto items2 = DragSender::Impl::ComposeItemsForDragging(3, data);
         XCTAssert( items2.size() == 1 );
         XCTAssert( items2[0].Filename() == "c" );         
    }
    { // dragging two selected items according to the sort method 
        data::Model data;
        data.Load(ProduceDummyListing({"..", "b", "a"}), data::Model::PanelType::Directory);
        data.CustomFlagsSelectSorted( data::SelectionBuilder{data}.SelectionByMask("*") );
        auto items1 = DragSender::Impl::ComposeItemsForDragging(1, data);
        XCTAssert( items1.size() == 2 );
        XCTAssert( items1[0].Filename() == "a" );
        XCTAssert( items1[1].Filename() == "b" ); 
        auto items2 = DragSender::Impl::ComposeItemsForDragging(2, data);
        XCTAssert( items2.size() == 2 );
        XCTAssert( items2[0].Filename() == "a" );
        XCTAssert( items2[1].Filename() == "b" );
          
        data::SortMode new_sort;
        new_sort.sort = data::SortMode::SortByNameRev;         
        data.SetSortMode( new_sort );
        auto items3 = DragSender::Impl::ComposeItemsForDragging(2, data);
        XCTAssert( items3.size() == 2 );
        XCTAssert( items3[0].Filename() == "b" );
        XCTAssert( items3[1].Filename() == "a" );        
    }
}

@end
