// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include "PanelBriefViewFixedWidthLayoutEngine.h"

using nc::panel::view::brief::FixedWidthLayoutEngine; 

// TODO: move this from XCTest to Catch2
@interface NCPanelBriefViewFixedWidthLayoutEngine_Tests : XCTestCase

@end

@implementation NCPanelBriefViewFixedWidthLayoutEngine_Tests

- (void)testEmptyByDefault
{
    FixedWidthLayoutEngine engine;
    
    XCTAssert( engine.ItemsNumber() == 0 );
    XCTAssert( engine.RowsNumber() == 0 );
    XCTAssert( engine.ColumnsNumber() == 0 );
    XCTAssert( NSEqualSizes( engine.ContentSize(), NSMakeSize(0.0, 0.0)) );
    XCTAssert( engine.ColumnsPositions().size() == 0 );
    XCTAssert( engine.ColumnsWidths().size() == 0 );
}

- (void)testRoundsNumberOfRowsDown
{
    FixedWidthLayoutEngine::Params params;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
 
    FixedWidthLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssert( engine.RowsNumber() == 3 );
}

- (void)testHandleCasesWhenNumberOfItemsDivisesByNumberOfRows
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    
    FixedWidthLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssert( engine.RowsNumber() == 3 );
    XCTAssert( engine.ColumnsNumber() == 10 );    
}

- (void)testHandleCasesWhenNumberOfItemsDoesntDivideByNumberOfRows
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 31;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    
    FixedWidthLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssert( engine.RowsNumber() == 3 );
    XCTAssert( engine.ColumnsNumber() == 11 );    
}

- (void)testReportsSizeOccupiedByItems
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    
    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    XCTAssertEqualWithAccuracy( engine.ContentSize().width, 500.0, 0.001);
    XCTAssertEqualWithAccuracy( engine.ContentSize().height, 60.0, 0.001);
}

- (void)testReportsColumnsPosititions
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    
    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    XCTAssert( engine.ColumnsPositions().size() == 10 );
    XCTAssertEqual( engine.ColumnsPositions()[0], 0);
    XCTAssertEqual( engine.ColumnsPositions()[1], 50);
    XCTAssertEqual( engine.ColumnsPositions()[8], 400);
    XCTAssertEqual( engine.ColumnsPositions()[9], 450);    
}

- (void)testReportsColumnsWidths
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    
    FixedWidthLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssert( engine.ColumnsWidths().size() == 10 );
    XCTAssertEqual( engine.ColumnsWidths()[0], 50);
    XCTAssertEqual( engine.ColumnsWidths()[1], 50);
    XCTAssertEqual( engine.ColumnsWidths()[8], 50);
    XCTAssertEqual( engine.ColumnsWidths()[9], 50);    
}

- (void)testProducesSaneItemAttributes
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    
    FixedWidthLayoutEngine engine;
    engine.Layout(params);
    
    auto attrs = engine.AttributesForItemNumber(29);
    XCTAssertEqual( attrs.indexPath.item, 29 );
    XCTAssertEqualWithAccuracy( attrs.frame.origin.x, 450.0, 0.001 );
    XCTAssertEqualWithAccuracy( attrs.frame.origin.y, 40.0, 0.001 );
    XCTAssertEqualWithAccuracy( attrs.frame.size.width, 50.0, 0.001 );
    XCTAssertEqualWithAccuracy( attrs.frame.size.height, 20.0, 0.001 );
}

- (void)testDoesntRequreRelayoutForWidthsChanges
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    
    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    XCTAssertEqual( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 1000, 65)), false );
    XCTAssertEqual( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 10, 65)), false );    
}

- (void)testDoesntRequreRelayoutForSmallHeightChanges
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    
    FixedWidthLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssertEqual( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 100, 60)), false );
    XCTAssertEqual( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 100, 79)), false );    
}

- (void)testDoesRequreRelayoutForSignificantHeightChanges
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    
    FixedWidthLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssertEqual( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 100, 50)), true );
    XCTAssertEqual( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 100, 80)), true );    
}

@end

