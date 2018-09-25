// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include <VFS/VFSListingInput.h>
#include "PanelData.h"
#include "PanelDataItemVolatileData.h"
#include "PanelView.h"
#include "QuickSearch.h"
#include <NimbleCommander/Bootstrap/Config.h>

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

static shared_ptr<VFSListing> ProduceDummyListing( const vector<string> &_filenames );
static shared_ptr<VFSListing> AppsListing();
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

- (int) quickSearchNeedsCursorPosition:(NCPanelQuickSearch*)_qs
{
    return self.cursorPosition;
}
- (void) quickSearch:(NCPanelQuickSearch*)_qs wantsToSetCursorPosition:(int)_cursor_position
{
    self.cursorPosition = _cursor_position;
}
- (void) quickSearchHasChangedVolatileData:(NCPanelQuickSearch*)_qs {}
- (void) quickSearchHasUpdatedData:(NCPanelQuickSearch*)_qs {}
- (void) quickSearch:(NCPanelQuickSearch*)_qs
wantsToSetSearchPrompt:(NSString*)_prompt
    withMatchesCount:(int)_count {}
@end

@interface QuickSearch_Tests : XCTestCase
@end

@implementation QuickSearch_Tests
{
    QuickSearch_MockDelegate *m_Delegate;
    data::Model m_Data;
    unique_ptr<GenericConfig> m_QSConfig;
}

- (void)setUp
{
    m_Data.Load(AppsListing(), data::Model::PanelType::Directory);
    m_Delegate = [[QuickSearch_MockDelegate alloc] init];
    m_QSConfig = make_unique<GenericConfig>( g_ConfigJSON );
}

- (void)tearDown
{
}

- (void)testBasicHardFiltering
{
    m_QSConfig->Set(g_ConfigIsSoftFiltering, false);
    m_QSConfig->Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:m_Data
                                              delegate:m_Delegate
                                                config:*m_QSConfig];
    
    auto request = @"box";
    [qs setSearchCriteria:request];
    XCTAssert( [qs.searchCriteria isEqualToString:request] );
    XCTAssert( m_Data.SortedEntriesCount() == 2 );
    XCTAssert( m_Data.EntryAtSortPosition(0).Filename() == "Dropbox.app" );
    XCTAssert( m_Data.EntryAtSortPosition(1).Filename() == "VirtualBox.app" );
    
    [qs setSearchCriteria:nil];
    XCTAssert( qs.searchCriteria == nil );
    XCTAssert( m_Data.SortedEntriesCount() == m_Data.RawEntriesCount() );
    
    request = @"asdawewaesafd";
    [qs setSearchCriteria:@"asdawewaesafd"];
    XCTAssert( [qs.searchCriteria isEqualToString:request] );
    XCTAssert( m_Data.SortedEntriesCount() == 0 );
    
    request = @"map";
    [qs setSearchCriteria:request];
    XCTAssert( [qs.searchCriteria isEqualToString:request] );
    XCTAssert( m_Data.SortedEntriesCount() == 1 );
    XCTAssert( m_Data.EntryAtSortPosition(0).Filename() == "Maps.app" );
}

- (void)testTypingForHardFiltering
{
    m_QSConfig->Set(g_ConfigIsSoftFiltering, false);
    m_QSConfig->Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    m_QSConfig->Set(g_ConfigKeyOption, (int)QuickSearch::KeyModif::WithoutModif);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:m_Data
                                              delegate:m_Delegate
                                                config:*m_QSConfig];
    NSEvent *e = nil;
    
    e = KeyDown(SingleCharStr(NSDeleteCharacter), 0);
    XCTAssert( [qs bidForHandlingKeyDown:e forPanelView:nil] == view::BiddingPriority::Skip );
    
    e = KeyDown(@"b", 0);
    XCTAssert( [qs bidForHandlingKeyDown:e forPanelView:nil] != view::BiddingPriority::Skip );
    [qs handleKeyDown:e forPanelView:nil];
    XCTAssert( [qs.searchCriteria isEqualToString:@"b"] );
    XCTAssert( m_Data.SortedEntriesCount() == 11 );
    
    e = KeyDown(@"o", 0);
    XCTAssert( [qs bidForHandlingKeyDown:e forPanelView:nil] != view::BiddingPriority::Skip );
    [qs handleKeyDown:e forPanelView:nil];
    XCTAssert( [qs.searchCriteria isEqualToString:@"bo"] );
    XCTAssert( m_Data.SortedEntriesCount() == 6 );
    
    e = KeyDown(@"x", 0);
    XCTAssert( [qs bidForHandlingKeyDown:e forPanelView:nil] != view::BiddingPriority::Skip );
    [qs handleKeyDown:e forPanelView:nil];
    XCTAssert( [qs.searchCriteria isEqualToString:@"box"] );
    XCTAssert( m_Data.SortedEntriesCount() == 2 );

    e = KeyDown(SingleCharStr(NSDeleteCharacter), 0);
    XCTAssert( [qs bidForHandlingKeyDown:e forPanelView:nil] != view::BiddingPriority::Skip );
    [qs handleKeyDown:e forPanelView:nil];
    XCTAssert( [qs.searchCriteria isEqualToString:@"bo"] );
    XCTAssert( m_Data.SortedEntriesCount() == 6 );
    
    [qs handleKeyDown:e forPanelView:nil];
    XCTAssert( [qs.searchCriteria isEqualToString:@"b"] );
    [qs handleKeyDown:e forPanelView:nil];
    XCTAssert( qs.searchCriteria == nil );
}

- (void)testModifiersOption
{
    m_QSConfig->Set(g_ConfigKeyOption, (int)QuickSearch::KeyModif::WithoutModif);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:m_Data
                                              delegate:m_Delegate
                                                config:*m_QSConfig];
    const auto skip = view::BiddingPriority::Skip;
    const auto caps = NSEventModifierFlagCapsLock;
    const auto shift = NSEventModifierFlagShift;
    const auto ctrl = NSEventModifierFlagControl;
    const auto alt = NSEventModifierFlagOption;
    const auto cmd = NSEventModifierFlagCommand;
    
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] != skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] != skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"A", caps|shift) forPanelView:nil] != skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl|alt) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", shift|alt) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip );
 
    m_QSConfig->Set(g_ConfigKeyOption, (int)QuickSearch::KeyModif::WithAlt);
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"A", caps|shift) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] != skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl|alt) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", shift|alt) forPanelView:nil] != skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip );

    m_QSConfig->Set(g_ConfigKeyOption, (int)QuickSearch::KeyModif::WithCtrlAlt);
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"A", caps|shift) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl|alt) forPanelView:nil] != skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", shift|alt) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip );

    m_QSConfig->Set(g_ConfigKeyOption, (int)QuickSearch::KeyModif::WithShiftAlt);
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"A", caps|shift) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl|alt) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", shift|alt) forPanelView:nil] != skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip );

    m_QSConfig->Set(g_ConfigKeyOption, (int)QuickSearch::KeyModif::Disabled);
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", 0) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", caps) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"A", caps|shift) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", alt) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", ctrl|alt) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", shift|alt) forPanelView:nil] == skip );
    XCTAssert( [qs bidForHandlingKeyDown:KeyDown(@"a", cmd) forPanelView:nil] == skip );
}

- (void)testUnderscoring
{
    m_QSConfig->Set(g_ConfigIsSoftFiltering, false);
    m_QSConfig->Set(g_ConfigTypingView, true);
    m_QSConfig->Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:m_Data
                                              delegate:m_Delegate
                                                config:*m_QSConfig];

    [qs setSearchCriteria:@"box"];
    XCTAssert( m_Data.VolatileDataAtSortPosition(0).qs_highlight_begin == 4 );
    XCTAssert( m_Data.VolatileDataAtSortPosition(0).qs_highlight_end == 7 );
    XCTAssert( m_Data.VolatileDataAtSortPosition(1).qs_highlight_begin == 7 );
    XCTAssert( m_Data.VolatileDataAtSortPosition(1).qs_highlight_end == 10 );
}

- (void)testBasicSoftFiltering
{
    m_QSConfig->Set(g_ConfigIsSoftFiltering, true);
    m_QSConfig->Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:m_Data
                                              delegate:m_Delegate
                                                config:*m_QSConfig];
    
    [qs setSearchCriteria:@"player"];
    
    XCTAssert( m_Data.EntriesBySoftFiltering().size() == 2 );
    XCTAssert( m_Data.EntriesBySoftFiltering()[0] == 15 );
    XCTAssert( m_Data.EntriesBySoftFiltering()[1] == 45 );
    
    XCTAssert( m_Delegate.cursorPosition == 15 );
}

- (void)testSoftTyping
{
    m_QSConfig->Set(g_ConfigIsSoftFiltering, true);
    m_QSConfig->Set(g_ConfigWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithData:m_Data
                                              delegate:m_Delegate
                                                config:*m_QSConfig];
    
    [qs handleKeyDown:KeyDown(@"p", 0) forPanelView:nil];
    XCTAssert( m_Delegate.cursorPosition == 0 );
    
    [qs handleKeyDown:KeyDown(@"l", 0) forPanelView:nil];
    XCTAssert( m_Delegate.cursorPosition == 9 );

    [qs handleKeyDown:KeyDown(@"a", 0) forPanelView:nil];
    XCTAssert( m_Delegate.cursorPosition == 9 );
    
    [qs handleKeyDown:KeyDown(@"y", 0) forPanelView:nil];
    XCTAssert( m_Delegate.cursorPosition == 15 );
    
    [qs handleKeyDown:KeyDown(SingleCharStr(NSDeleteCharacter), 0) forPanelView:nil];
    XCTAssert( m_Delegate.cursorPosition == 9 );
    
    [qs handleKeyDown:KeyDown(SingleCharStr(0xF701), 0) forPanelView:nil];
    XCTAssert( m_Delegate.cursorPosition == 15 );

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF701), 0) forPanelView:nil];
    XCTAssert( m_Delegate.cursorPosition == 45 );
    
    [qs handleKeyDown:KeyDown(SingleCharStr(0xF702), 0) forPanelView:nil];
    XCTAssert( m_Delegate.cursorPosition == 9 );
    
    [qs handleKeyDown:KeyDown(SingleCharStr(0xF703), 0) forPanelView:nil];
    XCTAssert( m_Delegate.cursorPosition == 45 );

    [qs handleKeyDown:KeyDown(SingleCharStr(0xF700), 0) forPanelView:nil];
    XCTAssert( m_Delegate.cursorPosition == 15 );
    
    [qs handleKeyDown:KeyDown(SingleCharStr(0xF700), 0) forPanelView:nil];
    XCTAssert( m_Delegate.cursorPosition == 9 );
}

@end

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

static shared_ptr<VFSListing> ProduceDummyListing( const vector<string> &_filenames )
{
    nc::vfs::ListingInput l;
    
    l.directories.reset( variable_container<>::type::common );
    l.directories[0] = "/";
    
    l.hosts.reset( variable_container<>::type::common );
    l.hosts[0] = VFSHost::DummyHost();
    
    for(auto &i: _filenames) {
        l.filenames.emplace_back(i);
        l.unix_modes.emplace_back(0);
        l.unix_types.emplace_back(0);
    }
    
    return VFSListing::Build(move(l));
}

static shared_ptr<VFSListing> AppsListing()
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
