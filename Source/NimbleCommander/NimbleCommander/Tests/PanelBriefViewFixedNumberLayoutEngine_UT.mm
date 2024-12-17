// Copyright (C) 2018-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <NimbleCommander/States/FilePanels/Brief/PanelBriefViewFixedNumberLayoutEngine.h>

using Catch::Approx;
using nc::panel::view::brief::FixedNumberLayoutEngine;

#define PREFIX "nc::panel::view::brief::FixedNumberLayoutEngine "

TEST_CASE(PREFIX "empty by default")
{
    const FixedNumberLayoutEngine engine;

    CHECK(engine.ItemsNumber() == 0);
    CHECK(engine.RowsNumber() == 0);
    CHECK(engine.ColumnsNumber() == 0);
    CHECK(NSEqualSizes(engine.ContentSize(), NSMakeSize(0.0, 0.0)));
    CHECK(engine.ColumnsPositions().empty());
    CHECK(engine.ColumnsWidths().empty());
}

TEST_CASE(PREFIX "rounds number of rows down")
{
    FixedNumberLayoutEngine::Params params;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedNumberLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.RowsNumber() == 3);
}

TEST_CASE(PREFIX "handle cases when number of items divises by number of rows")
{
    FixedNumberLayoutEngine::Params params;
    params.items_number = 30;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedNumberLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.RowsNumber() == 3);
    CHECK(engine.ColumnsNumber() == 10);
}

TEST_CASE(PREFIX "handle cases when number of items doesnt divide by number of rows")
{
    FixedNumberLayoutEngine::Params params;
    params.items_number = 31;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);

    FixedNumberLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.RowsNumber() == 3);
    CHECK(engine.ColumnsNumber() == 11);
}

TEST_CASE(PREFIX "distributes remaining width")
{
    FixedNumberLayoutEngine::Params params;
    params.items_number = 3;
    params.item_height = 20;
    params.columns_per_screen = 3;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 11, 20);

    FixedNumberLayoutEngine engine;
    engine.Layout(params);

    REQUIRE(engine.RowsNumber() == 1);
    REQUIRE(engine.ColumnsNumber() == 3);
    CHECK(engine.ContentSize().width == Approx(11.));
    CHECK(engine.ColumnsPositions()[0] == 0);
    CHECK(engine.ColumnsWidths()[0] == 4);
    CHECK(engine.ColumnsPositions()[1] == 4);
    CHECK(engine.ColumnsWidths()[1] == 4);
    CHECK(engine.ColumnsPositions()[2] == 8);
    CHECK(engine.ColumnsWidths()[2] == 3);
    CHECK(engine.AttributesForItemNumber(0).frame.size.width == Approx(4));
}

TEST_CASE(PREFIX "required relayout on width change")
{
    FixedNumberLayoutEngine::Params params;
    params.items_number = 3;
    params.item_height = 20;
    params.columns_per_screen = 3;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 11, 20);

    FixedNumberLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 11, 20)) == false);
    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 12, 20)) == true);
    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 10, 20)) == true);
}

TEST_CASE(PREFIX "required relayout on significant height change")
{
    FixedNumberLayoutEngine::Params params;
    params.items_number = 3;
    params.item_height = 20;
    params.columns_per_screen = 3;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 11, 20);

    FixedNumberLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 11, 20)) == false);
    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 11, 10)) == true);
    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 11, 39)) == false);
    CHECK(engine.ShouldRelayoutForNewBounds(NSMakeRect(0, 0, 11, 40)) == true);
}
