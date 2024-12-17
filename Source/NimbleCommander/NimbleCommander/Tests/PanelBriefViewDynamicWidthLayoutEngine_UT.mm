// Copyright (C) 2018-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <NimbleCommander/States/FilePanels/Brief/PanelBriefViewDynamicWidthLayoutEngine.h>

using Catch::Approx;
using nc::panel::view::brief::DynamicWidthLayoutEngine;

#define PREFIX "nc::panel::view::brief::DynamicWidthLayoutEngine "

TEST_CASE(PREFIX "empty by default")
{
    const DynamicWidthLayoutEngine engine;

    CHECK(engine.ItemsNumber() == 0);
    CHECK(engine.RowsNumber() == 0);
    CHECK(engine.ColumnsNumber() == 0);
    CHECK(NSEqualSizes(engine.ContentSize(), NSMakeSize(0.0, 0.0)));
    CHECK(engine.ColumnsPositions().empty());
    CHECK(engine.ColumnsWidths().empty());
}

TEST_CASE(PREFIX "rounds number of rows down")
{
    auto widths = std::vector<unsigned short>();
    DynamicWidthLayoutEngine::Params params;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    params.items_intrinsic_widths = &widths;

    DynamicWidthLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.RowsNumber() == 3);
}

TEST_CASE(PREFIX "handle cases when number of items divises by number of rows")
{
    auto widths = std::vector<unsigned short>(30, 50);
    DynamicWidthLayoutEngine::Params params;
    params.items_number = 30;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    params.items_intrinsic_widths = &widths;

    DynamicWidthLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.RowsNumber() == 3);
    CHECK(engine.ColumnsNumber() == 10);
}

TEST_CASE(PREFIX "handle cases when number ofI items doesnt divide by number of rows")
{
    auto widths = std::vector<unsigned short>(31, 50);
    DynamicWidthLayoutEngine::Params params;
    params.items_number = 31;
    params.item_height = 20;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    params.items_intrinsic_widths = &widths;

    DynamicWidthLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.RowsNumber() == 3);
    CHECK(engine.ColumnsNumber() == 11);
}

TEST_CASE(PREFIX "gets maximum width for every column")
{
    DynamicWidthLayoutEngine::Params params;
    params.items_number = 10;
    params.item_height = 20;
    params.item_min_width = 1;
    params.item_max_width = 1000;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    auto widths = std::vector<unsigned short>(10, 30);
    widths[2] = 50;
    widths[5] = 50;
    widths[8] = 50;
    params.items_intrinsic_widths = &widths;

    DynamicWidthLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.ContentSize().width == Approx(180.0));
    CHECK(engine.ContentSize().height == Approx(60.0));
    CHECK(engine.ColumnsWidths()[0] == 50);
    CHECK(engine.ColumnsWidths()[1] == 50);
    CHECK(engine.ColumnsWidths()[2] == 50);
    CHECK(engine.ColumnsWidths()[3] == 30);
    CHECK(engine.ColumnsPositions()[0] == 0);
    CHECK(engine.ColumnsPositions()[1] == 50);
    CHECK(engine.ColumnsPositions()[2] == 100);
    CHECK(engine.ColumnsPositions()[3] == 150);
}

TEST_CASE(PREFIX "does width clamping")
{
    DynamicWidthLayoutEngine::Params params;
    params.items_number = 10;
    params.item_height = 20;
    params.item_min_width = 35;
    params.item_max_width = 45;
    params.clip_view_bounds = NSMakeRect(0.0, 0.0, 100, 65);
    auto widths = std::vector<unsigned short>(10, 30);
    widths[2] = 50;
    widths[5] = 50;
    widths[8] = 50;
    params.items_intrinsic_widths = &widths;

    DynamicWidthLayoutEngine engine;
    engine.Layout(params);

    CHECK(engine.ContentSize().width == Approx(170.0));
    CHECK(engine.ContentSize().height == Approx(60.0));
    CHECK(engine.ColumnsWidths()[0] == 45);
    CHECK(engine.ColumnsWidths()[1] == 45);
    CHECK(engine.ColumnsWidths()[2] == 45);
    CHECK(engine.ColumnsWidths()[3] == 35);
    CHECK(engine.ColumnsPositions()[0] == 0);
    CHECK(engine.ColumnsPositions()[1] == 45);
    CHECK(engine.ColumnsPositions()[2] == 90);
    CHECK(engine.ColumnsPositions()[3] == 135);
}

TEST_CASE(PREFIX "finds items by rect")
{
    auto widths = std::vector<unsigned short>(10, 30);
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
        REQUIRE(items != nil);
        REQUIRE(items.count == 1);
        CHECK(items[0].indexPath.item == 9);
    }
    {
        auto items = engine.AttributesForItemsInRect(NSMakeRect(55., 0., 50., 500.));
        REQUIRE(items != nil);
        REQUIRE(items.count == 6);
        CHECK(items[0].indexPath.item == 3);
        CHECK(items[1].indexPath.item == 4);
        CHECK(items[2].indexPath.item == 5);
        CHECK(items[3].indexPath.item == 6);
        CHECK(items[4].indexPath.item == 7);
        CHECK(items[5].indexPath.item == 8);
    }
    {
        auto items = engine.AttributesForItemsInRect(NSMakeRect(10, 0., 10., 500.));
        REQUIRE(items != nil);
        REQUIRE(items.count == 3);
        CHECK(items[0].indexPath.item == 0);
        CHECK(items[1].indexPath.item == 1);
        CHECK(items[2].indexPath.item == 2);
    }
    {
        auto items = engine.AttributesForItemsInRect(NSMakeRect(10, 0., 10., 20.));
        REQUIRE(items != nil);
        REQUIRE(items.count == 1);
        CHECK(items[0].indexPath.item == 0);
    }
    {
        auto items = engine.AttributesForItemsInRect(NSMakeRect(10, 0., 10., 30.));
        REQUIRE(items != nil);
        REQUIRE(items.count == 2);
        CHECK(items[0].indexPath.item == 0);
        CHECK(items[1].indexPath.item == 1);
    }
}
