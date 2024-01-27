// Copyright (C) 2020-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <NimbleCommander/Core/FeedbackManagerImpl.h>
#include <Base/CFDefaultsCPP.h>

using namespace nc::base;
using nc::FeedbackManager;
using nc::FeedbackManagerImpl;

#define PREFIX "FeedbackManager "

static void ClearAll()
{
    CFDefaultsRemoveValue(FeedbackManagerImpl::g_RunsKey);
    CFDefaultsRemoveValue(FeedbackManagerImpl::g_HoursKey);
    CFDefaultsRemoveValue(FeedbackManagerImpl::g_FirstRunKey);
    CFDefaultsRemoveValue(FeedbackManagerImpl::g_LastRatingKey);
    CFDefaultsRemoveValue(FeedbackManagerImpl::g_LastRatingTimeKey);
}

TEST_CASE(PREFIX "sets first run time")
{
    ClearAll();
    std::time_t now = 123456;
    FeedbackManagerImpl fm([&] { return now; });
    const auto stored = CFDefaultsGetOptionalLong(FeedbackManagerImpl::g_FirstRunKey);
    REQUIRE(stored);
    CHECK(*stored == now);
}

TEST_CASE(PREFIX "doesn't change existing first run time")
{
    ClearAll();
    CFDefaultsSetLong(FeedbackManagerImpl::g_FirstRunKey, 10000);
    FeedbackManagerImpl fm([] { return 123456; });
    const auto stored = CFDefaultsGetOptionalLong(FeedbackManagerImpl::g_FirstRunKey);
    REQUIRE(stored);
    CHECK(*stored == 10000);
}

TEST_CASE(PREFIX "sets and increments runs count ")
{
    ClearAll();

    SECTION("Nothing initially")
    {
    }
    SECTION("initially zero")
    {
        CFDefaultsSetLong(FeedbackManagerImpl::g_RunsKey, 0);
    }
    SECTION("initially negative")
    {
        CFDefaultsSetLong(FeedbackManagerImpl::g_RunsKey, -777);
    }

    {
        FeedbackManagerImpl fm([] { return 123456; });
        const auto stored = CFDefaultsGetOptionalLong(FeedbackManagerImpl::g_RunsKey);
        REQUIRE(stored);
        CHECK(*stored == 1);
    }

    {
        FeedbackManagerImpl fm([] { return 123456; });
        const auto stored = CFDefaultsGetOptionalLong(FeedbackManagerImpl::g_RunsKey);
        REQUIRE(stored);
        CHECK(*stored == 2);
    }

    {
        FeedbackManagerImpl fm([] { return 123456; });
        const auto stored = CFDefaultsGetOptionalLong(FeedbackManagerImpl::g_RunsKey);
        REQUIRE(stored);
        CHECK(*stored == 3);
    }
}

TEST_CASE(PREFIX "Sets and updates number of hours used")
{
    ClearAll();
    std::time_t now = 123456;
    {
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.TotalHoursUsed() == Approx(0.));
        now += 60 * 60 * 6;
        fm.UpdateStatistics();
        const auto stored = CFDefaultsGetOptionalDouble(FeedbackManagerImpl::g_HoursKey);
        REQUIRE(stored);
        CHECK(*stored == Approx(6.));
    }
    {
        now += 60 * 60 * 10;
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.TotalHoursUsed() == Approx(6.));
        now += 60 * 60 * 5;
        fm.UpdateStatistics();
        const auto stored = CFDefaultsGetOptionalDouble(FeedbackManagerImpl::g_HoursKey);
        REQUIRE(stored);
        CHECK(*stored == Approx(11.));
    }
}

TEST_CASE(PREFIX "Shows feedback overlay only after a certain amount of usage")
{
    ClearAll();

    std::time_t now = 946684800; // 2000.01.01 00:00:00
    SECTION("No usage")
    {
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.IsEligibleForRatingOverlay() == false);
    }
    SECTION("Used for 10 days, 10 hours, 20 times")
    {
        CFDefaultsSetLong(FeedbackManagerImpl::g_FirstRunKey, now - 60 * 60 * 24 * 10);
        CFDefaultsSetDouble(FeedbackManagerImpl::g_HoursKey, 10.);
        CFDefaultsSetLong(FeedbackManagerImpl::g_RunsKey, 20);
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.IsEligibleForRatingOverlay() == true);
    }
    SECTION("Used for 9 days, 10 hours, 20 times")
    {
        CFDefaultsSetLong(FeedbackManagerImpl::g_FirstRunKey, now - 60 * 60 * 24 * 9);
        CFDefaultsSetDouble(FeedbackManagerImpl::g_HoursKey, 10.);
        CFDefaultsSetLong(FeedbackManagerImpl::g_RunsKey, 20);
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.IsEligibleForRatingOverlay() == false);
    }
    SECTION("Used for 10 days, 9 hours, 20 times")
    {
        CFDefaultsSetLong(FeedbackManagerImpl::g_FirstRunKey, now - 60 * 60 * 24 * 10);
        CFDefaultsSetDouble(FeedbackManagerImpl::g_HoursKey, 9.);
        CFDefaultsSetLong(FeedbackManagerImpl::g_RunsKey, 20);
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.IsEligibleForRatingOverlay() == false);
    }
    SECTION("Used for 10 days, 10 hours, 19 times")
    {
        CFDefaultsSetLong(FeedbackManagerImpl::g_FirstRunKey, now - 60 * 60 * 24 * 10);
        CFDefaultsSetDouble(FeedbackManagerImpl::g_HoursKey, 10.);
        CFDefaultsSetLong(FeedbackManagerImpl::g_RunsKey, 19);
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.IsEligibleForRatingOverlay() == false);
    }
}

TEST_CASE(PREFIX "Shows overlay only once is eligible")
{
    ClearAll();
    std::time_t now = 946684800; // 2000.01.01 00:00:00
    CFDefaultsSetLong(FeedbackManagerImpl::g_FirstRunKey, now - 60 * 60 * 24 * 10);
    CFDefaultsSetDouble(FeedbackManagerImpl::g_HoursKey, 10.);
    CFDefaultsSetLong(FeedbackManagerImpl::g_RunsKey, 20);
    FeedbackManagerImpl fm([&] { return now; });
    CHECK(fm.IsEligibleForRatingOverlay() == true);
    CHECK(fm.ShouldShowRatingOverlayView() == true);
    CHECK(fm.ShouldShowRatingOverlayView() == false);
}

TEST_CASE(PREFIX "Shows overlay after 14 days if it was discarded")
{
    ClearAll();
    std::time_t now = 946684800; // 2000.01.01 00:00:00
    CFDefaultsSetLong(FeedbackManagerImpl::g_FirstRunKey, now - 60 * 60 * 24 * 100);
    CFDefaultsSetDouble(FeedbackManagerImpl::g_HoursKey, 10.);
    CFDefaultsSetLong(FeedbackManagerImpl::g_RunsKey, 20);
    CFDefaultsSetInt(FeedbackManagerImpl::g_LastRatingKey, FeedbackManager::RatingDiscard);

    SECTION("15 days ago")
    {
        CFDefaultsSetLong(FeedbackManagerImpl::g_LastRatingTimeKey, now - 60 * 60 * 24 * 15);
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.IsEligibleForRatingOverlay() == true);
    }
    SECTION("14 days ago")
    {
        CFDefaultsSetLong(FeedbackManagerImpl::g_LastRatingTimeKey, now - 60 * 60 * 24 * 14);
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.IsEligibleForRatingOverlay() == true);
    }
    SECTION("13 days ago")
    {
        CFDefaultsSetLong(FeedbackManagerImpl::g_LastRatingTimeKey, now - 60 * 60 * 24 * 13);
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.IsEligibleForRatingOverlay() == false);
    }
}

TEST_CASE(PREFIX "Shows overlay after 365 days if it was rated")
{
    ClearAll();
    std::time_t now = 946684800; // 2000.01.01 00:00:00
    CFDefaultsSetLong(FeedbackManagerImpl::g_FirstRunKey, now - 60 * 60 * 24 * 100);
    CFDefaultsSetDouble(FeedbackManagerImpl::g_HoursKey, 10.);
    CFDefaultsSetLong(FeedbackManagerImpl::g_RunsKey, 20);
    CFDefaultsSetInt(FeedbackManagerImpl::g_LastRatingKey, FeedbackManager::Rating5Stars);

    SECTION("366 days ago")
    {
        CFDefaultsSetLong(FeedbackManagerImpl::g_LastRatingTimeKey, now - 60 * 60 * 24 * 366);
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.IsEligibleForRatingOverlay() == true);
    }
    SECTION("365 days ago")
    {
        CFDefaultsSetLong(FeedbackManagerImpl::g_LastRatingTimeKey, now - 60 * 60 * 24 * 365);
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.IsEligibleForRatingOverlay() == true);
    }
    SECTION("364 days ago")
    {
        CFDefaultsSetLong(FeedbackManagerImpl::g_LastRatingTimeKey, now - 60 * 60 * 24 * 364);
        FeedbackManagerImpl fm([&] { return now; });
        CHECK(fm.IsEligibleForRatingOverlay() == false);
    }
}

TEST_CASE(PREFIX "Saves ratings")
{
    ClearAll();
    std::time_t now = 946684800; // 2000.01.01 00:00:00
    CFDefaultsSetLong(FeedbackManagerImpl::g_FirstRunKey, now - 60 * 60 * 24 * 100);
    CFDefaultsSetDouble(FeedbackManagerImpl::g_HoursKey, 10.);
    CFDefaultsSetLong(FeedbackManagerImpl::g_RunsKey, 20);
    FeedbackManagerImpl fm([&] { return now; });
    fm.SetHasUI(false);
    const auto g_LastRatingKey = FeedbackManagerImpl::g_LastRatingKey;
    const auto g_LastRatingTimeKey = FeedbackManagerImpl::g_LastRatingTimeKey;
    SECTION("Discard")
    {
        fm.CommitRatingOverlayResult(FeedbackManager::RatingDiscard);
        REQUIRE(CFDefaultsGetOptionalInt(g_LastRatingKey));
        CHECK(CFDefaultsGetOptionalInt(g_LastRatingKey).value() == FeedbackManager::RatingDiscard);
    }
    SECTION("1 star")
    {
        fm.CommitRatingOverlayResult(FeedbackManager::Rating1Star);
        REQUIRE(CFDefaultsGetOptionalInt(g_LastRatingKey));
        CHECK(CFDefaultsGetOptionalInt(g_LastRatingKey).value() == FeedbackManager::Rating1Star);
    }
    SECTION("2 stars")
    {
        fm.CommitRatingOverlayResult(FeedbackManager::Rating2Stars);
        REQUIRE(CFDefaultsGetOptionalInt(g_LastRatingKey));
        CHECK(CFDefaultsGetOptionalInt(g_LastRatingKey).value() == FeedbackManager::Rating2Stars);
    }
    SECTION("3 stars")
    {
        fm.CommitRatingOverlayResult(FeedbackManager::Rating3Stars);
        REQUIRE(CFDefaultsGetOptionalInt(g_LastRatingKey));
        CHECK(CFDefaultsGetOptionalInt(g_LastRatingKey).value() == FeedbackManager::Rating3Stars);
    }
    SECTION("4 stars")
    {
        fm.CommitRatingOverlayResult(FeedbackManager::Rating4Stars);
        REQUIRE(CFDefaultsGetOptionalInt(g_LastRatingKey));
        CHECK(CFDefaultsGetOptionalInt(g_LastRatingKey).value() == FeedbackManager::Rating4Stars);
    }
    SECTION("5 stars")
    {
        fm.CommitRatingOverlayResult(FeedbackManager::Rating5Stars);
        REQUIRE(CFDefaultsGetOptionalInt(g_LastRatingKey));
        CHECK(CFDefaultsGetOptionalInt(g_LastRatingKey).value() == FeedbackManager::Rating5Stars);
    }
    REQUIRE(CFDefaultsGetOptionalLong(g_LastRatingTimeKey));
    CHECK(CFDefaultsGetOptionalLong(g_LastRatingTimeKey).value() == now);
}
