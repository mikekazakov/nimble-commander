// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <VFS/VFSListingInput.h>
#include <VFS/Host.h>
#include <Panel/PanelData.h>
#include <Panel/PanelDataItemVolatileData.h>
#include "QuickSearch.h"
#include <Config/ConfigImpl.h>
#include <Config/NonPersistentOverwritesStorage.h>
#include <memory>

#define PREFIX "QuickSearch "

using namespace nc::panel;
using namespace nc::panel::QuickSearch;
using namespace nc::panel::data;

static const auto g_ConfigJSON = "{\
\"filePanel\": {\
\"quickSearch\": {\
    \"typingView\": true,\
    \"softFiltering\": false,\
    \"whereToFind\": 0,\
    \"keyOption\": 3,\
    \"ignoreCharacters\": \" \"\
}}}";

static VFSListingPtr ProduceDummyListing(const std::vector<std::string> &_filenames);
static VFSListingPtr AppsListing();
static NSEvent *KeyDown(NSString *_key, NSEventModifierFlags _flags);
static NSString *SingleCharStr(unichar _c);

@interface QuickSearch_MockDelegate : NSObject <NCPanelQuickSearchDelegate>
@property(nonatomic) int cursorPosition;
@end

@implementation QuickSearch_MockDelegate
- (instancetype)init
{
    self = [super init];
    if( self )
        self.cursorPosition = -1;
    return self;
}
@synthesize cursorPosition;

- (int)quickSearchNeedsCursorPosition:(NCPanelQuickSearch *) [[maybe_unused]] _qs
{
    return self.cursorPosition;
}
- (void)quickSearch:(NCPanelQuickSearch *) [[maybe_unused]] _qs wantsToSetCursorPosition:(int)_cursor_position
{
    self.cursorPosition = _cursor_position;
}
- (void)quickSearchHasChangedVolatileData:(NCPanelQuickSearch *) [[maybe_unused]] _qs
{
}
- (void)quickSearchHasUpdatedData:(NCPanelQuickSearch *) [[maybe_unused]] _qs
{
}
- (void)quickSearch:(NCPanelQuickSearch *) [[maybe_unused]] _qs
    wantsToSetSearchPrompt:(NSString *) [[maybe_unused]] _prompt
          withMatchesCount:(int) [[maybe_unused]] _count
{
}
@end

struct QuickSearchTestsContext {
    QuickSearch_MockDelegate *delegate;
    data::Model data;
    nc::config::ConfigImpl qsconfig{g_ConfigJSON, std::make_shared<nc::config::NonPersistentOverwritesStorage>("")};
    QuickSearchTestsContext()
    {
        data.Load(AppsListing(), data::Model::PanelType::Directory);
        delegate = [[QuickSearch_MockDelegate alloc] init];
    }
};

TEST_CASE("basic hard filtering")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigIsSoftFiltering, false);
    ctx.qsconfig.Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data delegate:ctx.delegate config:ctx.qsconfig];

    auto request = @"box";
    [qs setSearchCriteria:request];
    CHECK([qs.searchCriteria isEqualToString:request]);
    CHECK(ctx.data.SortedEntriesCount() == 2);
    CHECK(ctx.data.EntryAtSortPosition(0).Filename() == "Dropbox.app");
    CHECK(ctx.data.EntryAtSortPosition(1).Filename() == "VirtualBox.app");

    [qs setSearchCriteria:nil];
    CHECK(qs.searchCriteria == nil);
    CHECK(ctx.data.SortedEntriesCount() == ctx.data.RawEntriesCount());

    request = @"asdawewaesafd";
    [qs setSearchCriteria:@"asdawewaesafd"];
    CHECK([qs.searchCriteria isEqualToString:request]);
    CHECK(ctx.data.SortedEntriesCount() == 0);

    request = @"map";
    [qs setSearchCriteria:request];
    CHECK([qs.searchCriteria isEqualToString:request]);
    CHECK(ctx.data.SortedEntriesCount() == 1);
    CHECK(ctx.data.EntryAtSortPosition(0).Filename() == "Maps.app");
}

TEST_CASE("typing for hard filtering")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigIsSoftFiltering, false);
    ctx.qsconfig.Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::WithoutModif));
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data delegate:ctx.delegate config:ctx.qsconfig];
    NSEvent *e = nil;

    e = KeyDown(SingleCharStr(NSDeleteCharacter), 0);
    CHECK([qs bidForHandlingKeyDown:e forPanelView:nil] == view::BiddingPriority::Skip);

    e = KeyDown(@"b", 0);
    CHECK([qs bidForHandlingKeyDown:e forPanelView:nil] != view::BiddingPriority::Skip);
    [qs handleKeyDown:e forPanelView:nil];
    CHECK([qs.searchCriteria isEqualToString:@"b"]);
    CHECK(ctx.data.SortedEntriesCount() == 11);

    e = KeyDown(@"o", 0);
    CHECK([qs bidForHandlingKeyDown:e forPanelView:nil] != view::BiddingPriority::Skip);
    [qs handleKeyDown:e forPanelView:nil];
    CHECK([qs.searchCriteria isEqualToString:@"bo"]);
    CHECK(ctx.data.SortedEntriesCount() == 6);

    e = KeyDown(@"x", 0);
    CHECK([qs bidForHandlingKeyDown:e forPanelView:nil] != view::BiddingPriority::Skip);
    [qs handleKeyDown:e forPanelView:nil];
    CHECK([qs.searchCriteria isEqualToString:@"box"]);
    CHECK(ctx.data.SortedEntriesCount() == 2);

    e = KeyDown(SingleCharStr(NSDeleteCharacter), 0);
    CHECK([qs bidForHandlingKeyDown:e forPanelView:nil] != view::BiddingPriority::Skip);
    [qs handleKeyDown:e forPanelView:nil];
    CHECK([qs.searchCriteria isEqualToString:@"bo"]);
    CHECK(ctx.data.SortedEntriesCount() == 6);

    [qs handleKeyDown:e forPanelView:nil];
    CHECK([qs.searchCriteria isEqualToString:@"b"]);
    [qs handleKeyDown:e forPanelView:nil];
    CHECK(qs.searchCriteria == nil);
}

TEST_CASE("modifiers option")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::WithoutModif));
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data delegate:ctx.delegate config:ctx.qsconfig];
    const auto skip = view::BiddingPriority::Skip;
    const auto caps = NSEventModifierFlagCapsLock;
    const auto shift = NSEventModifierFlagShift;
    const auto ctrl = NSEventModifierFlagControl;
    const auto alt = NSEventModifierFlagOption;
    const auto cmd = NSEventModifierFlagCommand;

    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] != skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] != skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"A", caps | shift) forPanelView:nil] != skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", ctrl | alt) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", shift | alt) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip);

    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::WithAlt));
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"A", caps | shift) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] != skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", ctrl | alt) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", shift | alt) forPanelView:nil] != skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip);

    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::WithCtrlAlt));
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"A", caps | shift) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", ctrl | alt) forPanelView:nil] != skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", shift | alt) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip);

    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::WithShiftAlt));
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"A", caps | shift) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", ctrl | alt) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", shift | alt) forPanelView:nil] != skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip);

    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::Disabled));
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"A", caps | shift) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", ctrl | alt) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", shift | alt) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip);
}

TEST_CASE("ignoring characters")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::WithoutModif));
    ctx.qsconfig.Set(g_ConfigIgnoreCharacters, "a ");
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data delegate:ctx.delegate config:ctx.qsconfig];
    const auto skip = view::BiddingPriority::Skip;
    CHECK([qs bidForHandlingKeyDown:KeyDown(@" ", 0) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"A", 0) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"b", 0) forPanelView:nil] != skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"B", 0) forPanelView:nil] != skip);

    ctx.qsconfig.Set(g_ConfigIgnoreCharacters, "b");
    CHECK([qs bidForHandlingKeyDown:KeyDown(@" ", 0) forPanelView:nil] != skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] != skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"A", 0) forPanelView:nil] != skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"b", 0) forPanelView:nil] == skip);
    CHECK([qs bidForHandlingKeyDown:KeyDown(@"B", 0) forPanelView:nil] == skip);
}

TEST_CASE("Underscoring")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigIsSoftFiltering, false);
    ctx.qsconfig.Set(g_ConfigTypingView, true);
    ctx.qsconfig.Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data delegate:ctx.delegate config:ctx.qsconfig];
    [qs setSearchCriteria:@"box"];
    CHECK(ctx.data.VolatileDataAtSortPosition(0).highlight.unpack().count == 1);
    CHECK(ctx.data.VolatileDataAtSortPosition(0).highlight.unpack().segments[0].offset == 4);
    CHECK(ctx.data.VolatileDataAtSortPosition(0).highlight.unpack().segments[0].length == 3);
    CHECK(ctx.data.VolatileDataAtSortPosition(1).highlight.unpack().count == 1);
    CHECK(ctx.data.VolatileDataAtSortPosition(1).highlight.unpack().segments[0].offset == 7);
    CHECK(ctx.data.VolatileDataAtSortPosition(1).highlight.unpack().segments[0].length == 3);
}

TEST_CASE("Different phrase locations")
{
    using Ranges = QuickSearchHiglight::Ranges;
    using Where = data::TextualFilter::Where;
    QuickSearchTestsContext ctx;
    NCPanelQuickSearch *qs;
    auto filter = [&](NSString *_crit, Where _where) {
        ctx.qsconfig.Set(g_ConfigIsSoftFiltering, false);
        ctx.qsconfig.Set(g_ConfigTypingView, true);
        ctx.qsconfig.Set(g_ConfigWhereToFind, _where);
        qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data delegate:ctx.delegate config:ctx.qsconfig];
        [qs setSearchCriteria:_crit];
        return qs;
    };
    SECTION("box, Anywhere")
    {
        filter(@"box", Where::Anywhere);
        REQUIRE(ctx.data.SortedEntriesCount() == 2);
        CHECK(ctx.data.VolatileDataAtSortPosition(0).highlight.unpack() == Ranges{{{4, 3}}, 1}); // "Dropbox.app"
        CHECK(ctx.data.VolatileDataAtSortPosition(1).highlight.unpack() == Ranges{{{7, 3}}, 1}); // "VirtualBox.app"
    }
    SECTION("box, Fuzzy")
    {
        filter(@"box", Where::Fuzzy);
        REQUIRE(ctx.data.SortedEntriesCount() == 2);
        CHECK(ctx.data.VolatileDataAtSortPosition(0).highlight.unpack() == Ranges{{{4, 3}}, 1}); // "Dropbox.app"
        CHECK(ctx.data.VolatileDataAtSortPosition(1).highlight.unpack() == Ranges{{{7, 3}}, 1}); // "VirtualBox.app"
    }
    SECTION("box, Beginning")
    {
        filter(@"box", Where::Beginning);
        REQUIRE(ctx.data.SortedEntriesCount() == 0);
    }
    SECTION("box, Ending")
    {
        filter(@"box", Where::Ending);
        REQUIRE(ctx.data.SortedEntriesCount() == 2);
        CHECK(ctx.data.VolatileDataAtSortPosition(0).highlight.unpack() == Ranges{{{4, 3}}, 1}); // "Dropbox.app"
        CHECK(ctx.data.VolatileDataAtSortPosition(1).highlight.unpack() == Ranges{{{7, 3}}, 1}); // "VirtualBox.app"
    }
    SECTION("box, BeginningOrEnding")
    {
        filter(@"box", Where::BeginningOrEnding);
        REQUIRE(ctx.data.SortedEntriesCount() == 2);
        CHECK(ctx.data.VolatileDataAtSortPosition(0).highlight.unpack() == Ranges{{{4, 3}}, 1}); // "Dropbox.app"
        CHECK(ctx.data.VolatileDataAtSortPosition(1).highlight.unpack() == Ranges{{{7, 3}}, 1}); // "VirtualBox.app"
    }

    SECTION("calap, Anywhere")
    {
        filter(@"calap", Where::Anywhere);
        REQUIRE(ctx.data.SortedEntriesCount() == 0);
    }
    SECTION("calap, Fuzzy")
    {
        filter(@"calap", Where::Fuzzy);
        REQUIRE(ctx.data.SortedEntriesCount() == 4);
        CHECK(ctx.data.VolatileDataAtSortPosition(0).highlight.unpack() ==
              Ranges{{{0, 3}, {11, 2}}, 2}); // "Calculator.app"
        CHECK(ctx.data.VolatileDataAtSortPosition(1).highlight.unpack() ==
              Ranges{{{0, 3}, {9, 2}}, 2}); // "Calendar.app"
        CHECK(ctx.data.VolatileDataAtSortPosition(2).highlight.unpack() ==
              Ranges{{{0, 1}, {8, 1}, {13, 1}, {18, 2}}, 4}); // "Counterparts Lite.app"
        CHECK(ctx.data.VolatileDataAtSortPosition(3).highlight.unpack() ==
              Ranges{{{0, 1}, {2, 1}, {6, 2}, {11, 1}}, 4}); // "CrashPlan.app"
    }
    SECTION("calap, Beginning")
    {
        filter(@"calap", Where::Beginning);
        REQUIRE(ctx.data.SortedEntriesCount() == 0);
    }
    SECTION("calap, Ending")
    {
        filter(@"calap", Where::Ending);
        REQUIRE(ctx.data.SortedEntriesCount() == 0);
    }
    SECTION("calap, BeginningOrEnding")
    {
        filter(@"calap", Where::BeginningOrEnding);
        REQUIRE(ctx.data.SortedEntriesCount() == 0);
    }
}

TEST_CASE("basic soft filtering")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigIsSoftFiltering, true);
    ctx.qsconfig.Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data delegate:ctx.delegate config:ctx.qsconfig];

    [qs setSearchCriteria:@"player"];

    CHECK(ctx.data.EntriesBySoftFiltering().size() == 2);
    CHECK(ctx.data.EntriesBySoftFiltering()[0] == 15);
    CHECK(ctx.data.EntriesBySoftFiltering()[1] == 45);

    CHECK(ctx.delegate.cursorPosition == 15);
}

TEST_CASE("soft typing")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigIsSoftFiltering, true);
    ctx.qsconfig.Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data delegate:ctx.delegate config:ctx.qsconfig];

    [qs handleKeyDown:KeyDown(@"p", 0) forPanelView:nil];
    CHECK(ctx.delegate.cursorPosition == 0);

    [qs handleKeyDown:KeyDown(@"l", 0) forPanelView:nil];
    CHECK(ctx.delegate.cursorPosition == 9);

    [qs handleKeyDown:KeyDown(@"a", 0) forPanelView:nil];
    CHECK(ctx.delegate.cursorPosition == 9);

    [qs handleKeyDown:KeyDown(@"y", 0) forPanelView:nil];
    CHECK(ctx.delegate.cursorPosition == 15);

    [qs handleKeyDown:KeyDown(SingleCharStr(NSDeleteCharacter), 0) forPanelView:nil];
    CHECK(ctx.delegate.cursorPosition == 9);

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF701), 0) forPanelView:nil];
    CHECK(ctx.delegate.cursorPosition == 15);

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF701), 0) forPanelView:nil];
    CHECK(ctx.delegate.cursorPosition == 45);

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF702), 0) forPanelView:nil];
    CHECK(ctx.delegate.cursorPosition == 9);

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF703), 0) forPanelView:nil];
    CHECK(ctx.delegate.cursorPosition == 45);

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF700), 0) forPanelView:nil];
    CHECK(ctx.delegate.cursorPosition == 15);

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF700), 0) forPanelView:nil];
    CHECK(ctx.delegate.cursorPosition == 9);
}

static NSEvent *KeyDown(NSString *_key, NSEventModifierFlags _flags)
{
    return [NSEvent keyEventWithType:NSEventTypeKeyDown
                            location:NSMakePoint(0, 0)
                       modifierFlags:_flags
                           timestamp:0
                        windowNumber:0
                             context:nil
                          characters:_key
         charactersIgnoringModifiers:_key
                           isARepeat:false
                             keyCode:0];
}

static NSString *SingleCharStr(unichar _c)
{
    return [NSString stringWithCharacters:&_c length:1];
}

static VFSListingPtr ProduceDummyListing(const std::vector<std::string> &_filenames)
{
    nc::vfs::ListingInput l;

    l.directories.reset(nc::base::variable_container<>::type::common);
    l.directories[0] = "/";

    l.hosts.reset(nc::base::variable_container<>::type::common);
    l.hosts[0] = VFSHost::DummyHost();

    for( auto &i : _filenames ) {
        l.filenames.emplace_back(i);
        l.unix_modes.emplace_back(0);
        l.unix_types.emplace_back(0);
    }

    return VFSListing::Build(std::move(l));
}

static VFSListingPtr AppsListing()
{
    return ProduceDummyListing({"App Store.app",
                                "Automator.app",
                                "Backup and Sync.app",
                                "Banktivity 5.app",
                                "Calculator.app",
                                "Calendar.app",
                                "Chess.app",
                                "Contacts.app",
                                "Counterparts Lite.app",
                                "CrashPlan.app",
                                "Dashboard.app",
                                "Dictionary.app",
                                "Dropbox.app",
                                "DropDMG.app",
                                "duet.app",
                                "DVD Player.app",
                                "FaceTime.app",
                                "Firefox.app",
                                "Font Book.app",
                                "freecol",
                                "Grammarly.app",
                                "GuitarPro.app",
                                "iBooks.app",
                                "Image Capture.app",
                                "iTunes.app",
                                "Keynote.app",
                                "LastPass.app",
                                "Launchpad.app",
                                "Mail.app",
                                "Maps.app",
                                "Messages.app",
                                "Microsoft Excel.app",
                                "Microsoft OneNote.app",
                                "Microsoft Outlook.app",
                                "Microsoft PowerPoint.app",
                                "Microsoft Word.app",
                                "Mission Control.app",
                                "Nimble Commander.app",
                                "Notes.app",
                                "Numbers.app",
                                "Pages.app",
                                "Parallels Desktop.app",
                                "Photo Booth.app",
                                "Photos.app",
                                "Preview.app",
                                "QuickTime Player.app",
                                "Reminders.app",
                                "Safari.app",
                                "Siri.app",
                                "Skype.app",
                                "Stickies.app",
                                "System Preferences.app",
                                "TextEdit.app",
                                "Time Machine.app",
                                "Tunnelblick.app",
                                "Utilities",
                                "uTorrent.app",
                                "VirtualBox.app",
                                "Xcode8.3.2.app",
                                "Xcode9.1.app"});
}
