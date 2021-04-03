// Copyright (C) 2018-2021 Michael Kazakov. Subject to GNU General Public License version 3.
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

static const auto g_ConfigJSON =
"{\
\"filePanel\": {\
\"quickSearch\": {\
    \"typingView\": true,\
    \"softFiltering\": false,\
    \"whereToFind\": 0,\
    \"keyOption\": 3\
}}}";

static VFSListingPtr ProduceDummyListing
    ( const std::vector<std::string> &_filenames );
static VFSListingPtr AppsListing();
static NSEvent *KeyDown(NSString *_key, NSEventModifierFlags _flags);
static NSString *SingleCharStr( unichar _c );

@interface QuickSearch_MockDelegate : NSObject<NCPanelQuickSearchDelegate>
@property (nonatomic) int cursorPosition;
@end

@implementation QuickSearch_MockDelegate
- (instancetype) init {
    if( self = [super init] )
        self.cursorPosition = -1;
    return self;
}

- (int) quickSearchNeedsCursorPosition:(NCPanelQuickSearch*)[[maybe_unused]]_qs
{
    return self.cursorPosition;
}
- (void) quickSearch:(NCPanelQuickSearch*)[[maybe_unused]]_qs wantsToSetCursorPosition:(int)_cursor_position
{
    self.cursorPosition = _cursor_position;
}
- (void) quickSearchHasChangedVolatileData:(NCPanelQuickSearch*)[[maybe_unused]]_qs {}
- (void) quickSearchHasUpdatedData:(NCPanelQuickSearch*)[[maybe_unused]]_qs {}
- (void) quickSearch:(NCPanelQuickSearch*)[[maybe_unused]]_qs
wantsToSetSearchPrompt:(NSString*)[[maybe_unused]]_prompt
    withMatchesCount:(int)[[maybe_unused]]_count {}
@end

struct QuickSearchTestsContext {
    QuickSearch_MockDelegate *delegate;
    data::Model data;
    nc::config::ConfigImpl qsconfig{g_ConfigJSON,
        std::make_shared<nc::config::NonPersistentOverwritesStorage>("")};
    QuickSearchTestsContext(){
        data.Load(AppsListing(), data::Model::PanelType::Directory);
        delegate = [[QuickSearch_MockDelegate alloc] init];
    }
};

TEST_CASE("basic hard filtering")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigIsSoftFiltering, false);
    ctx.qsconfig.Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data
                                              delegate:ctx.delegate
                                                config:ctx.qsconfig];

    auto request = @"box";
    [qs setSearchCriteria:request];
    CHECK( [qs.searchCriteria isEqualToString:request] );
    CHECK( ctx.data.SortedEntriesCount() == 2 );
    CHECK( ctx.data.EntryAtSortPosition(0).Filename() == "Dropbox.app" );
    CHECK( ctx.data.EntryAtSortPosition(1).Filename() == "VirtualBox.app" );

    [qs setSearchCriteria:nil];
    CHECK( qs.searchCriteria == nil );
    CHECK( ctx.data.SortedEntriesCount() == ctx.data.RawEntriesCount() );

    request = @"asdawewaesafd";
    [qs setSearchCriteria:@"asdawewaesafd"];
    CHECK( [qs.searchCriteria isEqualToString:request] );
    CHECK( ctx.data.SortedEntriesCount() == 0 );

    request = @"map";
    [qs setSearchCriteria:request];
    CHECK( [qs.searchCriteria isEqualToString:request] );
    CHECK( ctx.data.SortedEntriesCount() == 1 );
    CHECK( ctx.data.EntryAtSortPosition(0).Filename() == "Maps.app" );
}

TEST_CASE("typing for hard filtering")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigIsSoftFiltering, false);
    ctx.qsconfig.Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::WithoutModif));
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data
                                              delegate:ctx.delegate
                                                config:ctx.qsconfig];
    NSEvent *e = nil;

    e = KeyDown(SingleCharStr(NSDeleteCharacter), 0);
    CHECK( [qs bidForHandlingKeyDown:e forPanelView:nil] == view::BiddingPriority::Skip );

    e = KeyDown(@"b", 0);
    CHECK( [qs bidForHandlingKeyDown:e forPanelView:nil] != view::BiddingPriority::Skip );
    [qs handleKeyDown:e forPanelView:nil];
    CHECK( [qs.searchCriteria isEqualToString:@"b"] );
    CHECK( ctx.data.SortedEntriesCount() == 11 );

    e = KeyDown(@"o", 0);
    CHECK( [qs bidForHandlingKeyDown:e forPanelView:nil] != view::BiddingPriority::Skip );
    [qs handleKeyDown:e forPanelView:nil];
    CHECK( [qs.searchCriteria isEqualToString:@"bo"] );
    CHECK( ctx.data.SortedEntriesCount() == 6 );

    e = KeyDown(@"x", 0);
    CHECK( [qs bidForHandlingKeyDown:e forPanelView:nil] != view::BiddingPriority::Skip );
    [qs handleKeyDown:e forPanelView:nil];
    CHECK( [qs.searchCriteria isEqualToString:@"box"] );
    CHECK( ctx.data.SortedEntriesCount() == 2 );

    e = KeyDown(SingleCharStr(NSDeleteCharacter), 0);
    CHECK( [qs bidForHandlingKeyDown:e forPanelView:nil] != view::BiddingPriority::Skip );
    [qs handleKeyDown:e forPanelView:nil];
    CHECK( [qs.searchCriteria isEqualToString:@"bo"] );
    CHECK( ctx.data.SortedEntriesCount() == 6 );

    [qs handleKeyDown:e forPanelView:nil];
    CHECK( [qs.searchCriteria isEqualToString:@"b"] );
    [qs handleKeyDown:e forPanelView:nil];
    CHECK( qs.searchCriteria == nil );
}

TEST_CASE("modifiers option")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::WithoutModif));
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data
                                              delegate:ctx.delegate
                                                config:ctx.qsconfig];
    const auto skip = view::BiddingPriority::Skip;
    const auto caps = NSEventModifierFlagCapsLock;
    const auto shift = NSEventModifierFlagShift;
    const auto ctrl = NSEventModifierFlagControl;
    const auto alt = NSEventModifierFlagOption;
    const auto cmd = NSEventModifierFlagCommand;

    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] != skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] != skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"A", caps|shift) forPanelView:nil] != skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl|alt) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", shift|alt) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip );

    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::WithAlt));
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"A", caps|shift) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] != skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl|alt) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", shift|alt) forPanelView:nil] != skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip );

    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::WithCtrlAlt));
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"A", caps|shift) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl|alt) forPanelView:nil] != skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", shift|alt) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip );

    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::WithShiftAlt));
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"A", caps|shift) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl|alt) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", shift|alt) forPanelView:nil] != skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip );

    ctx.qsconfig.Set(g_ConfigKeyOption, static_cast<int>(QuickSearch::KeyModif::Disabled));
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"A", caps|shift) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl|alt) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", shift|alt) forPanelView:nil] == skip );
    CHECK( [qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip );
}

TEST_CASE("Underscoring")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigIsSoftFiltering, false);
    ctx.qsconfig.Set(g_ConfigTypingView, true);
    ctx.qsconfig.Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data
                                              delegate:ctx.delegate
                                                config:ctx.qsconfig];

    [qs setSearchCriteria:@"box"];
    CHECK( ctx.data.VolatileDataAtSortPosition(0).qs_highlight_begin == 4 );
    CHECK( ctx.data.VolatileDataAtSortPosition(0).qs_highlight_end == 7 );
    CHECK( ctx.data.VolatileDataAtSortPosition(1).qs_highlight_begin == 7 );
    CHECK( ctx.data.VolatileDataAtSortPosition(1).qs_highlight_end == 10 );
}

TEST_CASE("basic soft filtering")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigIsSoftFiltering, true);
    ctx.qsconfig.Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data
                                              delegate:ctx.delegate
                                                config:ctx.qsconfig];

    [qs setSearchCriteria:@"player"];

    CHECK( ctx.data.EntriesBySoftFiltering().size() == 2 );
    CHECK( ctx.data.EntriesBySoftFiltering()[0] == 15 );
    CHECK( ctx.data.EntriesBySoftFiltering()[1] == 45 );

    CHECK( ctx.delegate.cursorPosition == 15 );
}

TEST_CASE("soft typing")
{
    QuickSearchTestsContext ctx;
    ctx.qsconfig.Set(g_ConfigIsSoftFiltering, true);
    ctx.qsconfig.Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:ctx.data
                                              delegate:ctx.delegate
                                                config:ctx.qsconfig];

    [qs handleKeyDown:KeyDown(@"p", 0) forPanelView:nil];
    CHECK( ctx.delegate.cursorPosition == 0 );

    [qs handleKeyDown:KeyDown(@"l", 0) forPanelView:nil];
    CHECK( ctx.delegate.cursorPosition == 9 );

    [qs handleKeyDown:KeyDown(@"a", 0) forPanelView:nil];
    CHECK( ctx.delegate.cursorPosition == 9 );

    [qs handleKeyDown:KeyDown(@"y", 0) forPanelView:nil];
    CHECK( ctx.delegate.cursorPosition == 15 );

    [qs handleKeyDown:KeyDown(SingleCharStr(NSDeleteCharacter), 0) forPanelView:nil];
    CHECK( ctx.delegate.cursorPosition == 9 );

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF701), 0) forPanelView:nil];
    CHECK( ctx.delegate.cursorPosition == 15 );

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF701), 0) forPanelView:nil];
    CHECK( ctx.delegate.cursorPosition == 45 );

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF702), 0) forPanelView:nil];
    CHECK( ctx.delegate.cursorPosition == 9 );

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF703), 0) forPanelView:nil];
    CHECK( ctx.delegate.cursorPosition == 45 );

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF700), 0) forPanelView:nil];
    CHECK( ctx.delegate.cursorPosition == 15 );

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF700), 0) forPanelView:nil];
    CHECK( ctx.delegate.cursorPosition == 9 );
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

static NSString *SingleCharStr( unichar _c )
{
    return [NSString stringWithCharacters:&_c length:1];
}

static VFSListingPtr ProduceDummyListing( const std::vector<std::string> &_filenames )
{
    nc::vfs::ListingInput l;
    
    l.directories.reset( nc::base::variable_container<>::type::common );
    l.directories[0] = "/";
    
    l.hosts.reset( nc::base::variable_container<>::type::common );
    l.hosts[0] = VFSHost::DummyHost();
    
    for(auto &i: _filenames) {
        l.filenames.emplace_back(i);
        l.unix_modes.emplace_back(0);
        l.unix_types.emplace_back(0);
    }
    
    return VFSListing::Build(std::move(l));
}

static VFSListingPtr AppsListing()
{
    return ProduceDummyListing({
    "App Store.app",
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
