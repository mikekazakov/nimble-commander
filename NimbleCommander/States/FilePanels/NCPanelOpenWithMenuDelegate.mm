// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NCPanelOpenWithMenuDelegate.h"
#include <NimbleCommander/Core/LaunchServices.h>
#include <Sparkle/Sparkle.h>
#include <Utility/SystemInformation.h>
#include <Utility/ObjCpp.h>
#include <Utility/UTI.h>
#include <VFS/VFS.h>
#include "PanelAux.h"
#include "PanelController.h"
#include <Habanero/SerialQueue.h>
#include <set>

using namespace nc::core;
using namespace nc::panel;
using nc::utility::UTIDB;

namespace {

struct FetchResult
{
    std::vector<LaunchServiceHandler>handlers;
    std::string default_handler_path;
    std::string uti;
};

static void SortAndPurgeDuplicateHandlers(std::vector<LaunchServiceHandler> &_handlers)
{
    sort(begin(_handlers), end(_handlers), [](const auto &_1st, const auto &_2nd){
        return [_1st.Name() localizedCompare:_2nd.Name()] < 0;
    });

    for(int i = 0; i < (int)_handlers.size() - 1;) {
        if([_handlers[i].Name() isEqualToString:_handlers[i+1].Name()] &&
           [_handlers[i].Identifier() isEqualToString:_handlers[i+1].Identifier()]){
            // choose the latest version
            // TODO: remove sparkle here, switch to something more lightweight
            if([[SUStandardVersionComparator defaultComparator] compareVersion:_handlers[i].Version()
                toVersion:_handlers[i+1].Version()] >= NSOrderedSame)
            { // _handlers[i] has later version or they are the same
                _handlers.erase(_handlers.begin() + i + 1);
                
            }
            else
            { // _handlers[i+1] has later version
                _handlers.erase(_handlers.begin() + i);
                continue;
            }
        }
        ++i;
    }
}

static FetchResult FetchHandlers(const std::vector<VFSListingItem> &_items, const UTIDB& _db)
{
    std::vector<LauchServicesHandlers> per_item_handlers;
    for( auto &i: _items )
        per_item_handlers.emplace_back( LauchServicesHandlers{i, _db} );
    
    LauchServicesHandlers items_handlers{per_item_handlers};
    
    std::vector<LaunchServiceHandler> handlers;
    for( const auto &path: items_handlers.HandlersPaths() )
        try {
            handlers.emplace_back( LaunchServiceHandler(path) );
        }
        catch(...) {
        }
    
    SortAndPurgeDuplicateHandlers(handlers);
    
    stable_partition(begin(handlers),
                     end(handlers),
                     [&](const auto &_i){ return _i.Path() == items_handlers.DefaultHandlerPath(); });


    FetchResult result;
    result.handlers = move(handlers);
    result.default_handler_path = items_handlers.DefaultHandlerPath();
    result.uti = items_handlers.CommonUTI();
    return result;
}

}

@implementation NCPanelOpenWithMenuDelegate
{
    std::vector<VFSListingItem>      m_ContextItems;
    std::vector<LaunchServiceHandler>m_OpenWithHandlers;
    std::string m_DefaultHandlerPath;
    std::string m_ItemsUTI;
    SerialQueue                     m_FetchQueue;
    std::set<NSMenu*>               m_ManagedMenus;
    FileOpener                     *m_FileOpener;
    const UTIDB                    *m_UTIDB;
}

- (instancetype)initWithFileOpener:(nc::panel::FileOpener&)_file_opener
                             utiDB:(const nc::utility::UTIDB&)_uti_db
{
    if( self = [super init] ) {
        m_FileOpener = &_file_opener;
        m_UTIDB = &_uti_db;
    }
    return self;
}

+ (NSString*) regularMenuIdentifier
{
    return @"regular";
}

+ (NSString*) alwaysOpenWithMenuIdentifier
{
    return @"always";
}

- (void) setContextSource:(const std::vector<VFSListingItem>)_items
{
    m_ContextItems = move(_items);
}

- (BOOL)menuHasKeyEquivalent:(NSMenu*)[[maybe_unused]]_menu
                    forEvent:(NSEvent*)[[maybe_unused]]_event
                      target:(__nullable id* __nonnull)[[maybe_unused]]_target
                      action:(__nullable SEL* __nonnull)[[maybe_unused]]_action
{
    return false;
}

- (void)fetchHandlers
{
    if( !m_FetchQueue.Empty() )
        return;

    auto source_items = m_ContextItems.empty() && self.target != nil ?
        std::make_shared<std::vector<VFSListingItem>>(self.target.selectedEntriesOrFocusedEntry) :
        std::make_shared<std::vector<VFSListingItem>>(m_ContextItems);
    
    m_FetchQueue.Run([source_items, self]{
        auto f = std::make_shared<FetchResult>(FetchHandlers(*source_items, *m_UTIDB));
        dispatch_to_main_queue([f, self]{
            [self acceptFetchResult:f];
        });
    });
}

- (void)acceptFetchResult:(std::shared_ptr<FetchResult>)_result
{
    m_OpenWithHandlers = move(_result->handlers);
    m_DefaultHandlerPath = move(_result->default_handler_path);
    m_ItemsUTI = move(_result->uti);
    
    const auto run_loop = NSRunLoop.currentRunLoop;
    if( ![run_loop.currentMode isEqualToString:NSEventTrackingRunLoopMode] )
        return;
    
    [NSRunLoop.currentRunLoop performSelector:@selector(updateAfterFetching)
                                       target:self
                                     argument:nil
                                        order:0
                                        modes:@[NSEventTrackingRunLoopMode]];
}

- (void)updateAfterFetching
{
    for( auto menu: m_ManagedMenus )
        [self updateMenuWithBuiltHandlers:menu];
}

- (NSMenuItem*) makeDefaultHandlerItem:(const LaunchServiceHandler&)_handler
{
    const auto item = [NSMenuItem new];
    item.title = [NSString stringWithFormat:@"%@ (%@)",
                  _handler.Name(),
                  NSLocalizedStringFromTable(@"default", @"FilePanelsContextMenu",  "Menu item postfix marker for default apps to open with, for English is 'default'")];
    item.image = [_handler.Icon() copy];
    item.image.size = NSMakeSize(16, 16);
    item.target = self;
    item.action = @selector(OnOpenWith:);
    return item;
}

- (NSMenuItem*) makeRegularHandlerItem:(const LaunchServiceHandler&)_handler
{
    const auto item = [NSMenuItem new];
    item.title = _handler.Name();
    item.image = [_handler.Icon() copy];
    item.image.size = NSMakeSize(16, 16);
    item.target = self;
    item.action = @selector(OnOpenWith:);
    return item;
}

- (void)updateMenuWithBuiltHandlers:(NSMenu*)menu
{
    [menu removeAllItems];
    if( !m_OpenWithHandlers.empty() ) {
        int start = 0;
        if( m_OpenWithHandlers.front().Path() == m_DefaultHandlerPath ) {
            auto menu_item = [self makeDefaultHandlerItem:m_OpenWithHandlers.front()];
            menu_item.tag = 0;
            [menu addItem:menu_item];
            [menu addItem:NSMenuItem.separatorItem];
            start++;
        }
    
        for( int i = start; i < (int)m_OpenWithHandlers.size(); ++i ) {
            auto menu_item = [self makeRegularHandlerItem:m_OpenWithHandlers[i]];
            menu_item.tag = i;
            [menu addItem:menu_item];
        }

        if( start < (int)m_OpenWithHandlers.size() )
            [menu addItem:NSMenuItem.separatorItem];
    }
    else {
        [menu addItem:[self makeNoneStubItem]];
        [menu addItem:NSMenuItem.separatorItem];
    }
    
    if( nc::utility::GetOSXVersion() < nc::utility::OSXVersion::OSX_14 ) {
        // After the MAS redisign the old way for querying with UTI doesn't work anymore.
        // No substitute was found so far.
        if( !m_ItemsUTI.empty() )
            [menu addItem:[self makeSearchInMASItem]];
    }
    
    [menu addItem:[self makeOpenWithOtherItem]];
}

- (void)addManagedMenu:(NSMenu*)_menu
{
    m_ManagedMenus.emplace(_menu);
}

- (void)menuNeedsUpdate:(NSMenu*)menu
{
    [self fetchHandlers];

    [menu removeAllItems];
    [menu addItem:[self makeFetchingStubItem]];
}

- (NSMenuItem*) makeSearchInMASItem
{
    auto item = [NSMenuItem new];
    item.title = NSLocalizedStringFromTable(@"App Store...",
                                            @"FilePanelsContextMenu",
                                            "Menu item to choose an app from MAS");
    item.target = self;
    item.action = @selector(OnSearchInMAS:);
    return item;
}

- (NSMenuItem*) makeOpenWithOtherItem
{
    auto item = [NSMenuItem new];
    item.title = NSLocalizedStringFromTable(@"Other...",
        @"FilePanelsContextMenu",
        "Menu item to choose other app to open with, for English is 'Other...'");
    item.target = self;
    item.action = @selector(OnOpenWithOther:);
    return item;
}

- (NSMenuItem*) makeNoneStubItem
{
    auto title = NSLocalizedStringFromTable(
        @"<None>",
        @"FilePanelsContextMenu",
        "Menu item for case when no handlers are available, for English is '<None>'");
    auto item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    item.enabled = false;
    return item;
}

- (NSMenuItem*) makeFetchingStubItem
{
    auto title = NSLocalizedStringFromTable(
        @"Fetching...",
        @"FilePanelsContextMenu",
        "Menu item for indicating that fetching process is in progress");
    return [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
}

- (bool)isAlwaysOpenWith:(NSMenu*)_menu
{
    return [_menu.identifier isEqualToString:NCPanelOpenWithMenuDelegate.alwaysOpenWithMenuIdentifier];
}

- (void)OnOpenWith:(id)sender
{
    if( const auto menu_item = objc_cast<NSMenuItem>(sender) ) {
        const auto app_no = menu_item.tag;
        assert(app_no >= 0 && app_no < (long)m_OpenWithHandlers.size());
        const auto &handler = m_OpenWithHandlers[app_no];
        [self openItemsWithHandler:handler];
        if( [self isAlwaysOpenWith:menu_item.menu] )
            handler.SetAsDefaultHandlerForUTI(m_ItemsUTI);
    }
}

static NSOpenPanel* BuildAppChoose()
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = false;
    panel.canChooseFiles = true;
    panel.canChooseDirectories = false;
    panel.allowedFileTypes = @[@"app"];
    panel.directoryURL = [[NSURL alloc] initFileURLWithPath:@"/Applications" isDirectory:true];
    return panel;
}

static void ShowOpenPanel(NSOpenPanel *_panel,
                          NSWindow *_window,
                          std::function<void(const std::string&_path)> _on_ok )
{
    [_panel beginSheetModalForWindow:_window
                  completionHandler:^(NSInteger result) {
                      if(result == NSFileHandlingPanelOKButton)
                          _on_ok( _panel.URL.path.fileSystemRepresentation );
                  }];
}

- (void)OnOpenWithOther:(id)sender
{
    if( const auto menu_item = objc_cast<NSMenuItem>(sender) ) {
        ShowOpenPanel( BuildAppChoose(), self.target.window, [=](auto _path){
            try {
                LaunchServiceHandler handler{_path};
                [self openItemsWithHandler:handler];
                if( [self isAlwaysOpenWith:menu_item.menu] )
                    handler.SetAsDefaultHandlerForUTI(m_ItemsUTI);
            }
            catch(...){
            }
        });
    }
}

- (void) openItemsWithHandler:(const LaunchServiceHandler&)_handler
{
    const auto &source_items = m_ContextItems.empty() && self.target != nil ?
        self.target.selectedEntriesOrFocusedEntry :
        m_ContextItems;

    if( source_items.size() > 1 ) {
        const auto same_host = all_of( begin(source_items), end(source_items), [&](const auto &i){
            return i.Host() == source_items.front().Host();
          });
        if( same_host ) {
            std::vector<std::string> items;
            for(auto &i: source_items)
                items.emplace_back( i.Path() );
            m_FileOpener->Open(items,
                               source_items.front().Host(),
                               _handler.Identifier(),
                               self.target);
        }
    }
    else if( source_items.size() == 1 ) {
        m_FileOpener->Open(source_items.front().Path(),
                           source_items.front().Host(),
                           _handler.Path(),
                           self.target);
    }
}

- (void)OnSearchInMAS:(id)[[maybe_unused]]_sender
{
    auto format = @"macappstores://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/docTypeLookup?uti=%s";
    NSString *mas_url = [NSString stringWithFormat:format, m_ItemsUTI.c_str()];
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:mas_url]];
}


@end
