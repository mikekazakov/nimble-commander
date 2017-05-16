#include "NCPanelOpenWithMenuDelegate.h"
#include <NimbleCommander/Core/LaunchServices.h>
#include <Sparkle/Sparkle.h>
#include <VFS/VFS.h>
#include "PanelAux.h"
#include "PanelController.h"

using namespace nc::core;
using namespace nc::panel;

@implementation NCPanelOpenWithMenuDelegate
{
    vector<VFSListingItem>          m_ContextItems;
    bool                            m_HandlersAreBuilt;
    vector<LaunchServiceHandler>    m_OpenWithHandlers;
    string                          m_DefaultHandlerPath;
    string                          m_ItemsUTI;
}

- (instancetype) init
{
    self = [super init];
    if( self ) {
        m_HandlersAreBuilt = false;
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

- (void) setContextSource:(const vector<VFSListingItem>)_items
{
    m_ContextItems = move(_items);
}


- (BOOL)menuHasKeyEquivalent:(NSMenu*)menu
                    forEvent:(NSEvent*)event
                      target:(__nullable id* __nullable)target
                      action:(__nullable SEL* __nullable)action
{
    return false;
}

static void SortAndPurgeDuplicateHandlers(vector<LaunchServiceHandler> &_handlers)
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

- (void)fetchHandlers
{
    vector<LauchServicesHandlers> per_item_handlers;
    for(auto &i: m_ContextItems)
        per_item_handlers.emplace_back( LauchServicesHandlers{i} );
    
    LauchServicesHandlers items_handlers{per_item_handlers};
    m_DefaultHandlerPath = items_handlers.DefaultHandlerPath();
    m_ItemsUTI = items_handlers.CommonUTI();

    for( const auto &path: items_handlers.HandlersPaths() )
        try {
            m_OpenWithHandlers.emplace_back( LaunchServiceHandler(path) );
        }
    catch(...){
    }
    
    SortAndPurgeDuplicateHandlers(m_OpenWithHandlers);
    stable_partition(begin(m_OpenWithHandlers),
                     end(m_OpenWithHandlers),
                     [&](const auto &_i){ return _i.Path() == m_DefaultHandlerPath; });
    
    m_HandlersAreBuilt = true;
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

- (void)menuNeedsUpdate:(NSMenu*)menu
{
    if( !m_HandlersAreBuilt )
        [self fetchHandlers];
    
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
    
        for( int i = start; i < m_OpenWithHandlers.size(); ++i ) {
            auto menu_item = [self makeRegularHandlerItem:m_OpenWithHandlers[i]];
            menu_item.tag = i;
            [menu addItem:menu_item];
        }

        if( start < m_OpenWithHandlers.size() )
            [menu addItem:NSMenuItem.separatorItem];
    }
    else {
        [menu addItem:[self makeNoneStubItem]];
        [menu addItem:NSMenuItem.separatorItem];
    }
    
    if( !m_ItemsUTI.empty() )
        [menu addItem:[self makeSearchInMASItem]];
    
    [menu addItem:[self makeOpenWithOtherItem]];
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
        assert(app_no >= 0 && app_no < m_OpenWithHandlers.size());
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
                          function<void(const string&_path)> _on_ok )
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
    const auto &source_items = m_ContextItems;
    
    if( source_items.size() > 1 ) {
        const auto same_host = all_of( begin(source_items), end(source_items), [&](const auto &i){
            return i.Host() == source_items.front().Host();
          });
        if( same_host ) {
            vector<string> items;
            for(auto &i: source_items)
                items.emplace_back( i.Path() );
            PanelVFSFileWorkspaceOpener::Open(items,
                                              source_items.front().Host(),
                                              _handler.Identifier(),
                                              self.target);
        }
    }
    else if( source_items.size() == 1 ) {
        PanelVFSFileWorkspaceOpener::Open(source_items.front().Path(),
                                          source_items.front().Host(),
                                          _handler.Path(),
                                          self.target);
    }
}

- (void)OnSearchInMAS:(id)sender
{
    auto format = @"macappstores://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/docTypeLookup?uti=%s";
    NSString *mas_url = [NSString stringWithFormat:format, m_ItemsUTI.c_str()];
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:mas_url]];
}


@end
