// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include "PanelBriefViewDynamicWidthLayoutEngine.h"

using nc::panel::view::brief::DynamicWidthLayoutEngine; 

// TODO: move this from XCTest to Catch2
@interface NCPanelBriefViewDynamicWidthLayoutEngine_Tests : XCTestCase

@end

@implementation NCPanelBriefViewDynamicWidthLayoutEngine_Tests

- (void)testEmptyByDefault
{
    DynamicWidthLayoutEngine engine;
    
    XCTAssert( engine.ItemsNumber() == 0 );
    XCTAssert( engine.RowsNumber() == 0 );
    XCTAssert( engine.ColumnsNumber() == 0 );
    XCTAssert( NSEqualSizes( engine.ContentSize(), NSMakeSize(0.0, 0.0)) );
    XCTAssert( engine.ColumnsPositions().size() == 0 );
    XCTAssert( engine.ColumnsWidths().size() == 0 );
}

- (void)testRoundsNumberOfRowsDown
{
    auto widths = std::vector<short>();
    DynamicWidthLayoutEngine::Params params;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    params.items_intrinsic_widths = &widths;
    
    DynamicWidthLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssert( engine.RowsNumber() == 3 );
}

- (void)testHandleCasesWhenNumberOfItemsDivisesByNumberOfRows
{
    auto widths = std::vector<short>(30, 50);
    DynamicWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    params.items_intrinsic_widths = &widths;
    
    DynamicWidthLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssert( engine.RowsNumber() == 3 );
    XCTAssert( engine.ColumnsNumber() == 10 );    
}

- (void)testHandleCasesWhenNumberOfItemsDoesntDivideByNumberOfRows
{
    auto widths = std::vector<short>(31, 50);    
    DynamicWidthLayoutEngine::Params params;
    params.items_number = 31;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    params.items_intrinsic_widths = &widths;
    
    DynamicWidthLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssert( engine.RowsNumber() == 3 );
    XCTAssert( engine.ColumnsNumber() == 11 );    
}

- (void)testGetsMaximumWidthForEveryColumn
{
    DynamicWidthLayoutEngine::Params params;
    params.items_number = 10;
    params.item_height = 20;
    params.item_min_width = 1;
    params.item_max_width = 1000;    
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    auto widths = std::vector<short>(10, 30); 
    widths[2] = 50;
    widths[5] = 50;
    widths[8] = 50;
    params.items_intrinsic_widths = &widths;
    
    DynamicWidthLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssertEqualWithAccuracy( engine.ContentSize().width, 180.0, 0.001 );
    XCTAssertEqualWithAccuracy( engine.ContentSize().height, 60.0, 0.001 );
    XCTAssertEqual( engine.ColumnsWidths()[0], 50 );
    XCTAssertEqual( engine.ColumnsWidths()[1], 50 );
    XCTAssertEqual( engine.ColumnsWidths()[2], 50 );
    XCTAssertEqual( engine.ColumnsWidths()[3], 30 );
    XCTAssertEqual( engine.ColumnsPositions()[0], 0 );
    XCTAssertEqual( engine.ColumnsPositions()[1], 50 );
    XCTAssertEqual( engine.ColumnsPositions()[2], 100 );
    XCTAssertEqual( engine.ColumnsPositions()[3], 150 );
}

- (void)testDoesWidthClamping
{
    DynamicWidthLayoutEngine::Params params;
    params.items_number = 10;
    params.item_height = 20;
    params.item_min_width = 35;
    params.item_max_width = 45;    
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    auto widths = std::vector<short>(10, 30); 
    widths[2] = 50;
    widths[5] = 50;
    widths[8] = 50;
    params.items_intrinsic_widths = &widths;
    
    DynamicWidthLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssertEqualWithAccuracy( engine.ContentSize().width, 170.0, 0.001 );
    XCTAssertEqualWithAccuracy( engine.ContentSize().height, 60.0, 0.001 );
    XCTAssertEqual( engine.ColumnsWidths()[0], 45 );
    XCTAssertEqual( engine.ColumnsWidths()[1], 45 );
    XCTAssertEqual( engine.ColumnsWidths()[2], 45 );
    XCTAssertEqual( engine.ColumnsWidths()[3], 35 );
    XCTAssertEqual( engine.ColumnsPositions()[0], 0 );
    XCTAssertEqual( engine.ColumnsPositions()[1], 45 );
    XCTAssertEqual( engine.ColumnsPositions()[2], 90 );
    XCTAssertEqual( engine.ColumnsPositions()[3], 135 );
}

- (void)testFindsItemsByRect
{
    auto widths = std::vector<short>(10, 30); 
    widths[2] = 50;
    widths[5] = 50;
    widths[8] = 50;
        
    DynamicWidthLayoutEngine::Params params;
    params.items_number = 10;
    params.item_height = 20;
    params.item_min_width = 1;
    params.item_max_width = 1000;    
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    params.items_intrinsic_widths = &widths;
    
    DynamicWidthLayoutEngine engine;
    engine.Layout(params);
    
    {
        auto items = engine.AttributesForItemsInRect(NSMakeRect(150., 0., 500., 500.));
        XCTAssert( items != nil );
        XCTAssertEqual( (int)items.count, 1 );
        XCTAssertEqual( items[0].indexPath.item, 9 );
    }
    {
        auto items = engine.AttributesForItemsInRect(NSMakeRect(55., 0., 50., 500.));
        XCTAssert( items != nil );
        XCTAssertEqual( (int)items.count, 6 );
        XCTAssertEqual( items[0].indexPath.item, 3 );
        XCTAssertEqual( items[1].indexPath.item, 4 );
        XCTAssertEqual( items[2].indexPath.item, 5 );
        XCTAssertEqual( items[3].indexPath.item, 6 );
        XCTAssertEqual( items[4].indexPath.item, 7 );
        XCTAssertEqual( items[5].indexPath.item, 8 );        
    }
    {
        auto items = engine.AttributesForItemsInRect(NSMakeRect(10, 0., 10., 500.));
        XCTAssert( items != nil );
        XCTAssertEqual( (int)items.count, 3 );
        XCTAssertEqual( items[0].indexPath.item, 0 );
        XCTAssertEqual( items[1].indexPath.item, 1 );
        XCTAssertEqual( items[2].indexPath.item, 2 );
    }
    {
        auto items = engine.AttributesForItemsInRect(NSMakeRect(10, 0., 10., 20.));
        XCTAssert( items != nil );
        XCTAssertEqual( (int)items.count, 1 );
        XCTAssertEqual( items[0].indexPath.item, 0 );
    }
    {
        auto items = engine.AttributesForItemsInRect(NSMakeRect(10, 0., 10., 30.));
        XCTAssert( items != nil );
        XCTAssertEqual( (int)items.count, 2 );
        XCTAssertEqual( items[0].indexPath.item, 0 );
        XCTAssertEqual( items[1].indexPath.item, 1 );
    }    
}

@end
