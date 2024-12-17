// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <NimbleCommander/States/FilePanels/Brief/PanelBriefViewFixedWidthLayoutEngine.h>

using Catch::Approx;
using nc::panel::view::brief::FixedWidthLayoutEngine;

#define PREFIX "nc::panel::view::brief::FixedWidthLayoutEngine "

TEST_CASE(PREFIX "empty by default")
{
    const FixedWidthLayoutEngine engine;

    CHECK(engine.ItemsNumber() == 0);
    CHECK(engine.RowsNumber() == 0);
    CHECK(engine.ColumnsNumber() == 0);
    CHECK(NSEqualSizes(engine.ContentSize(), NSMakeSize(0.0, 0.0)));
    CHECK(engine.ColumnsPositions().empty());
    CHECK(engine.ColumnsWidths().empty());
}

TEST_CASE(PREFIX "rounds number of rows down")
{
    FixedWidthLayoutEngine::Params params;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.RowsNumber() == 3);
}

TEST_CASE(PREFIX "handle cases when number of items divises by number of rows")
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.RowsNumber() == 3);
    CHECK(engine.ColumnsNumber() == 10);
}

TEST_CASE(PREFIX "handle cases when number of items doesnt divide by number of rows")
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 31;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.RowsNumber() == 3);
    CHECK(engine.ColumnsNumber() == 11);
}

TEST_CASE(PREFIX "reports size occupied by items")
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.ContentSize().width == Approx(500.0));
    CHECK(engine.ContentSize().height == Approx(60.0));
}

TEST_CASE(PREFIX "reports columns posititions")
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    REQUIRE(engine.ColumnsPositions().size() == 10);
    CHECK(engine.ColumnsPositions()[0] == 0);
    CHECK(engine.ColumnsPositions()[1] == 50);
    CHECK(engine.ColumnsPositions()[8] == 400);
    CHECK(engine.ColumnsPositions()[9] == 450);
}

TEST_CASE(PREFIX "reports columns widths")
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    REQUIRE(engine.ColumnsWidths().size() == 10);
    CHECK(engine.ColumnsWidths()[0] == 50);
    CHECK(engine.ColumnsWidths()[1] == 50);
    CHECK(engine.ColumnsWidths()[8] == 50);
    CHECK(engine.ColumnsWidths()[9] == 50);
}

TEST_CASE(PREFIX "produces sane item attributes")
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    auto attrs = engine.AttributesForItemNumber(29);
    CHECK(attrs.indexPath.item == 29);
    CHECK(attrs.frame.origin.x == Approx(450.0));
    CHECK(attrs.frame.origin.y == Approx(40.0));
    CHECK(attrs.frame.size.width == Approx(50.0));
    CHECK(attrs.frame.size.height == Approx(20.0));
}

TEST_CASE(PREFIX "doesnt requre relayout for widths changes")
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 1000, 65)) == false);
    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 10, 65)) == false);
}

TEST_CASE(PREFIX "doesnt requre relayout for small height changes")
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 100, 60)) == false);
    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 100, 79)) == false);
}

TEST_CASE(PREFIX "does requre relayout for significant height changes")
{
    FixedWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_width = 50;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedWidthLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 100, 50)) == true);
    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 100, 80)) == true);
}
