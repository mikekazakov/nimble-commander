// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include "PanelBriefViewFixedNumberLayoutEngine.h"

using nc::panel::view::brief::FixedNumberLayoutEngine; 

// TODO: move this from XCTest to Catch2
@interface NCPanelBriefViewFixedNumberLayoutEngine_Tests : XCTestCase

@end

@implementation NCPanelBriefViewFixedNumberLayoutEngine_Tests

- (void)testEmptyByDefault
{
    FixedNumberLayoutEngine engine;
    
    XCTAssert( engine.ItemsNumber() == 0 );
    XCTAssert( engine.RowsNumber() == 0 );
    XCTAssert( engine.ColumnsNumber() == 0 );
    XCTAssert( NSEqualSizes( engine.ContentSize(), NSMakeSize(0.0, 0.0)) );
    XCTAssert( engine.ColumnsPositions().size() == 0 );
    XCTAssert( engine.ColumnsWidths().size() == 0 );
}

- (void)testRoundsNumberOfRowsDown
{
    FixedNumberLayoutEngine::Params params;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    
    FixedNumberLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssert( engine.RowsNumber() == 3 );
}

- (void)testHandleCasesWhenNumberOfItemsDivisesByNumberOfRows
{
    FixedNumberLayoutEngine::Params params;
    params.items_number = 30;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    
    FixedNumberLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssert( engine.RowsNumber() == 3 );
    XCTAssert( engine.ColumnsNumber() == 10 );    
}

- (void)testHandleCasesWhenNumberOfItemsDoesntDivideByNumberOfRows
{    
    FixedNumberLayoutEngine::Params params;
    params.items_number = 31;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    
    FixedNumberLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssert( engine.RowsNumber() == 3 );
    XCTAssert( engine.ColumnsNumber() == 11 );    
}

- (void)testDistributesRemainingWidth
{    
    FixedNumberLayoutEngine::Params params;
    params.items_number = 3;
    params.item_height = 20;
    params.columns_per_screen = 3;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 11, 20);
    
    FixedNumberLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssert( engine.RowsNumber() == 1 );
    XCTAssert( engine.ColumnsNumber() == 3 );
    XCTAssertEqualWithAccuracy( engine.ContentSize().width, 11, 0.001 );
    XCTAssertEqual( engine.ColumnsPositions()[0], 0 );
    XCTAssertEqual( engine.ColumnsWidths()[0], 4 );
    XCTAssertEqual( engine.ColumnsPositions()[1], 4 );
    XCTAssertEqual( engine.ColumnsWidths()[1], 4 );
    XCTAssertEqual( engine.ColumnsPositions()[2], 8 );
    XCTAssertEqual( engine.ColumnsWidths()[2], 3 );
    XCTAssertEqualWithAccuracy( engine.AttributesForItemNumber(0).frame.size.width, 4, 0.001 );    
}

- (void)testRequiredRelayoutOnWidthChange
{    
    FixedNumberLayoutEngine::Params params;
    params.items_number = 3;
    params.item_height = 20;
    params.columns_per_screen = 3;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 11, 20);
    
    FixedNumberLayoutEngine engine;
    engine.Layout(params);

    XCTAssert( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 11, 20)) == false );
    XCTAssert( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 12, 20)) == true );
    XCTAssert( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 10, 20)) == true );
}
    
- (void)testRequiredRelayoutOnSignificantHeightChange
{    
    FixedNumberLayoutEngine::Params params;
    params.items_number = 3;
    params.item_height = 20;
    params.columns_per_screen = 3;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 11, 20);
    
    FixedNumberLayoutEngine engine;
    engine.Layout(params);
    
    XCTAssert( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 11, 20)) == false );
    XCTAssert( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 11, 10)) == true );
    XCTAssert( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 11, 39)) == false );
    XCTAssert( engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 11, 40)) == true );    
}


@end
