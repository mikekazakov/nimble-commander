#import <XCTest/XCTest.h>
#include <VFS/VFSListingInput.h>
#include "PanelData.h"
#include "PanelView.h"
#include "QuickSearch.h"
#include "PanelViewLayoutSupport.h"
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

//static const auto g_ConfigQuickSearchWhereToFind                = "filePanel.quickSearch.whereToFind";
//static const auto g_ConfigQuickSearchSoftFiltering              = "filePanel.quickSearch.softFiltering";
//static const auto g_ConfigQuickSearchTypingView                 = "filePanel.quickSearch.typingView";
//static const auto g_ConfigQuickSearchKeyOption                  = "filePanel.quickSearch.keyOption";


@interface QuickSearch_Tests : XCTestCase

@end


@implementation QuickSearch_Tests
{
    PanelView *m_View;
    data::Model m_Data;
    unique_ptr<GenericConfig> m_QSConfig;
}

- (void)setUp
{
    m_Data.Load(AppsListing(), data::Model::PanelType::Directory);
    m_View = [[PanelView alloc] initWithFrame:NSMakeRect(0, 0, 400, 400)
                                       layout:*PanelViewLayoutsStorage::LastResortLayout()];
    m_View.data = &m_Data;
    m_QSConfig = make_unique<GenericConfig>( g_ConfigJSON );
}

- (void)tearDown
{
}

- (void)testBasicHardFiltering
{
    m_QSConfig->Set(g_ConfigQuickSearchSoftFiltering, false);
    m_QSConfig->Set(g_ConfigQuickSearchWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithView:m_View data:m_Data config:*m_QSConfig];
    
    auto request = @"box";
    [qs setSearchCriteria:request];
    XCTAssert( [qs.searchCriteria isEqualToString:request] );
    XCTAssert( m_Data.SortedEntriesCount() == 2 );
    XCTAssert( m_Data.EntryAtSortPosition(1).Filename() == "VirtualBox.app" );
    XCTAssert( m_Data.EntryAtSortPosition(0).Filename() == "Dropbox.app" );
    
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
    m_QSConfig->Set(g_ConfigQuickSearchSoftFiltering, false);
    m_QSConfig->Set(g_ConfigQuickSearchWhereToFind, data::TextualFilter::Where::Anywhere);
    auto qs = [[NCPanelQuickSearch alloc] initWithView:m_View data:m_Data config:*m_QSConfig];
    NSEvent *e = nil;
    
    e = KeyDown(SingleCharStr(NSDeleteCharacter), 0);
    XCTAssert( [qs bidForHandlingKeyDown:e forPanelView:m_View] == view::BiddingPriority::Skip );
    
    e = KeyDown(@"b", 0);
    XCTAssert( [qs bidForHandlingKeyDown:e forPanelView:m_View] != view::BiddingPriority::Skip );
    [qs handleKeyDown:e forPanelView:m_View];
    XCTAssert( [qs.searchCriteria isEqualToString:@"b"] );
    XCTAssert( m_Data.SortedEntriesCount() == 11 );
    
    e = KeyDown(@"o", 0);
    XCTAssert( [qs bidForHandlingKeyDown:e forPanelView:m_View] != view::BiddingPriority::Skip );
    [qs handleKeyDown:e forPanelView:m_View];
    XCTAssert( [qs.searchCriteria isEqualToString:@"bo"] );
    XCTAssert( m_Data.SortedEntriesCount() == 6 );
    
    e = KeyDown(@"x", 0);
    XCTAssert( [qs bidForHandlingKeyDown:e forPanelView:m_View] != view::BiddingPriority::Skip );
    [qs handleKeyDown:e forPanelView:m_View];
    XCTAssert( [qs.searchCriteria isEqualToString:@"box"] );
    XCTAssert( m_Data.SortedEntriesCount() == 2 );

    e = KeyDown(SingleCharStr(NSDeleteCharacter), 0);
    XCTAssert( [qs bidForHandlingKeyDown:e forPanelView:m_View] != view::BiddingPriority::Skip );
    [qs handleKeyDown:e forPanelView:m_View];
    XCTAssert( [qs.searchCriteria isEqualToString:@"bo"] );
    XCTAssert( m_Data.SortedEntriesCount() == 6 );
    
    [qs handleKeyDown:e forPanelView:m_View];
    XCTAssert( [qs.searchCriteria isEqualToString:@"b"] );
    [qs handleKeyDown:e forPanelView:m_View];
    XCTAssert( qs.searchCriteria == nil );
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
