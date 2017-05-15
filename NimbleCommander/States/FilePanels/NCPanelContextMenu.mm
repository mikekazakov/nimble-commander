#include <sys/stat.h>
#include <Sparkle/Sparkle.h>
#include "NCPanelContextMenu.h"
#include "PanelAux.h"
#include <NimbleCommander/Core/LaunchServices.h>
#include "PanelController.h"
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include "Actions/CopyToPasteboard.h"
#include "Actions/Delete.h"
#include "Actions/Duplicate.h"
#include "Actions/Compress.h"

using namespace nc::core;
using namespace nc::panel;

struct OpenWithHandler
{
    string path;
    NSString *app_name;
    NSImage  *app_icon;
    NSString *app_version;
    NSString *app_id;
    
    bool is_default;
    
    inline bool operator<(const OpenWithHandler& _r) const
    {
        return [app_name localizedCompare:_r.app_name] < 0;
    }
};

static bool ExposeOpenWithHandler(const string &_path, OpenWithHandler &_hndl)
{
//    static const double icon_size = [NSFont systemFontSize];
    static const double icon_size = 14; // hard-coding is bad, but line above gives 13., which looks worse
    
    NSString *path = [NSString stringWithUTF8String:_path.c_str()];
    NSBundle *handler_bundle = [NSBundle bundleWithPath:path];
    if(handler_bundle == nil)
        return false;
    
    NSString *bundle_id = [handler_bundle bundleIdentifier];
    NSString* version = [[handler_bundle infoDictionary] objectForKey:@"CFBundleVersion"];
    
    NSString *appName = [[NSFileManager defaultManager] displayNameAtPath: path];
    NSImage *appicon = [[NSWorkspace sharedWorkspace] iconForFile:path];
    [appicon setSize:NSMakeSize(icon_size, icon_size)];
    
    _hndl.is_default = false;
    _hndl.path = _path;
    _hndl.app_name = appName;
    _hndl.app_icon = appicon;
    _hndl.app_version = version;
    _hndl.app_id = bundle_id;
    
    return true;
}

static void PurgeDuplicateHandlers(vector<OpenWithHandler> &_handlers)
{
    // _handlers should be already sorted here
    for(int i = 0; i < (int)_handlers.size() - 1;)
    {
        if([_handlers[i].app_name isEqualToString:_handlers[i+1].app_name] &&
           [_handlers[i].app_id isEqualToString:_handlers[i+1].app_id]
           )
        {
            // choose the latest version
            if([[SUStandardVersionComparator defaultComparator] compareVersion:_handlers[i].app_version
                toVersion:_handlers[i+1].app_version] >= NSOrderedSame)
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

static NSOpenPanel* BuildAppChoose()
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = NO;
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowedFileTypes = @[@"app"];
    panel.directoryURL = [[NSURL alloc] initFileURLWithPath:@"/Applications" isDirectory:true];
    return panel;
}

static void ShowOpenPanel( NSOpenPanel *_panel, NSWindow *_window, function<void(const string&_path)> _on_ok )
{
    [_panel beginSheetModalForWindow:_window
                  completionHandler:^(NSInteger result) {
                      if(result == NSFileHandlingPanelOKButton)
                          _on_ok( _panel.URL.path.fileSystemRepresentation );
                  }];
}

template <typename T, typename E, typename C>
T common_or_default_element(const C& _container, const T& _default, E _extract)
{
    auto i = begin(_container), e = end(_container);
    if( i == e )
        return _default;
    auto &first = *i;
    ++i;
    
    for( ; i != e; ++i )
        if( _extract(*i) != _extract(first) )
            return _default;

    return _extract(first);
}


@implementation NCPanelContextMenu
{
    string                              m_CommonDir;  // may be "" in case of non-uniform listing
    VFSHostPtr                          m_CommonHost; // may be nullptr in case of non-uniform listing
    vector<VFSListingItem>              m_Items;
    vector<OpenWithHandler>             m_OpenWithHandlers;
    string                              m_ItemsUTI;
    MainWindowFilePanelState           *m_MainWnd;
    PanelController                    *m_Panel;
    NSMutableArray                     *m_ShareItemsURLs;
    int                                 m_DirsCount;
    int                                 m_FilesCount;
    unique_ptr<actions::PanelAction>    m_CopyAction;
    unique_ptr<actions::PanelAction>    m_MoveToTrashAction;
    unique_ptr<actions::PanelAction>    m_DeletePermanentlyAction;
    unique_ptr<actions::PanelAction>    m_DuplicateAction;
    unique_ptr<actions::PanelAction>    m_CompressHereAction;
    unique_ptr<actions::PanelAction>    m_CompressToOppositeAction;
}

- (instancetype) initWithItems:(vector<VFSListingItem>)_items
                       ofPanel:(PanelController*)_panel
{
    if( _items.empty() )
        throw invalid_argument("NCPanelContextMenu.initWithData - there's no items");
    self = [super init];
    if(self) {
        m_Panel = _panel;
        m_DirsCount = m_FilesCount = 0;
        m_Items = move(_items);
        m_DirsCount = (int)count_if(begin(m_Items), end(m_Items), [](auto &i) { return i.IsDir(); });
        m_FilesCount = (int)count_if(begin(m_Items), end(m_Items), [](auto &i) { return i.IsReg(); });
        m_CommonHost = common_or_default_element( m_Items, VFSHostPtr{}, [](auto &_) -> const VFSHostPtr& { return _.Host(); } );
        m_CommonDir = common_or_default_element( m_Items, ""s, [](auto &_) -> const string& { return _.Directory(); } );

        self.delegate = self;
        self.minimumWidth = 200; // hardcoding is bad!
    
        m_CopyAction.reset( new actions::context::CopyToPasteboard{m_Items} );
        m_MoveToTrashAction.reset( new actions::context::MoveToTrash{m_Items} );
        m_DeletePermanentlyAction.reset( new actions::context::DeletePermanently{m_Items} );
        m_DuplicateAction.reset( new actions::context::Duplicate{m_Items} );
        m_CompressHereAction.reset( new actions::context::CompressHere{m_Items} );
        m_CompressToOppositeAction.reset( new actions::context::CompressToOpposite{m_Items} );
        [self doStuffing];
    }
    return self;
}

- (void)menuDidClose:(NSMenu *)menu
{
    [m_Panel contextMenuDidClose:menu];
}

- (void) doStuffing
{
    //////////////////////////////////////////////////////////////////////
    // regular Open item
    if(m_FilesCount > 0 || ( m_CommonHost && m_CommonHost->IsNativeFS() ) ) {
        NSMenuItem *item = [NSMenuItem new];
        item.title = NSLocalizedStringFromTable(@"Open", @"FilePanelsContextMenu", "Menu item title for opening a file by default, for English is 'Open'");
        item.target = self;
        item.action = @selector(OnRegularOpen:);
        [self addItem:item];
    }

    //////////////////////////////////////////////////////////////////////
    // Open With... stuff
    {
        list<LauchServicesHandlers> per_item_handlers;
        for(auto &i: m_Items)
            per_item_handlers.emplace_back( LauchServicesHandlers::GetForItem(i) );
        
        LauchServicesHandlers items_handlers;
        LauchServicesHandlers::DoMerge(per_item_handlers, items_handlers);
        
        m_ItemsUTI = items_handlers.uti;

        NSMenu *openwith_submenu = [NSMenu new];
        NSMenu *always_openwith_submenu = [NSMenu new];
        
        // prepare open with handlers information
        for(int i = 0; i < items_handlers.paths.size(); ++i)
        {
            OpenWithHandler h;
            if(ExposeOpenWithHandler(items_handlers.paths[i], h))
            {
                if(items_handlers.default_path == i)
                    h.is_default = true;
                m_OpenWithHandlers.push_back(h);
            }
        }
        
        // sort them using it's user-friendly name
        sort(m_OpenWithHandlers.begin(), m_OpenWithHandlers.end());
        
        // get rid of duplicates in handlers list
        PurgeDuplicateHandlers(m_OpenWithHandlers);
        
        // show default handler if any
        bool any_handlers_added = false;
        bool any_non_default_handlers_added = false;
        for(int i = 0; i < m_OpenWithHandlers.size(); ++i)
            if(m_OpenWithHandlers[i].is_default) {
                NSMenuItem *item = [NSMenuItem new];
                item.title = [NSString stringWithFormat:@"%@ (%@)",
                              m_OpenWithHandlers[i].app_name,
                              NSLocalizedStringFromTable(@"default", @"FilePanelsContextMenu",  "Menu item postfix marker for default apps to open with, for English is 'default'")];
                item.image = m_OpenWithHandlers[i].app_icon;
                item.tag = i;
                item.target = self;
                item.action = @selector(OnOpenWith:);
                [openwith_submenu addItem:item];
                
                item = [item copy];
                item.action = @selector(OnAlwaysOpenWith:);
                [always_openwith_submenu addItem:item];

                [openwith_submenu addItem:NSMenuItem.separatorItem];
                [always_openwith_submenu addItem:NSMenuItem.separatorItem];
                any_handlers_added = true;
                break;
            }

        // show other handlers
        for( int i = 0; i < m_OpenWithHandlers.size(); ++i )
            if( !m_OpenWithHandlers[i].is_default ) {
                NSMenuItem *item = [NSMenuItem new];
                item.title = m_OpenWithHandlers[i].app_name;
                item.image = m_OpenWithHandlers[i].app_icon;
                item.tag = i;
                item.target = self;
                item.action = @selector(OnOpenWith:);
                [openwith_submenu addItem:item];
                
                item = [item copy];
                item.action = @selector(OnAlwaysOpenWith:);
                [always_openwith_submenu addItem:item];
                
                any_handlers_added = true;
                any_non_default_handlers_added = true;
            }

        // separate them
        if(!any_handlers_added) {
            NSString *title = NSLocalizedStringFromTable(@"<None>", @"FilePanelsContextMenu", "Menu item for case when no handlers are available, for English is '<None>'");
            [openwith_submenu addItem:[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""]];
            [always_openwith_submenu addItem:[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""]];
        }
        
        if(any_non_default_handlers_added || !any_handlers_added) {
            [openwith_submenu addItem:NSMenuItem.separatorItem];
            [always_openwith_submenu addItem:NSMenuItem.separatorItem];
        }
        
        // let user to select program manually
        NSMenuItem *item = [NSMenuItem new];
        item.title = NSLocalizedStringFromTable(@"Other...", @"FilePanelsContextMenu", "Menu item to choose other app to open with, for English is 'Other...'");
        item.target = self;
        item.action = @selector(OnOpenWithOther:);
        [openwith_submenu addItem:item];
        
        item = [item copy];
        item.action = @selector(OnAlwaysOpenWithOther:);
        [always_openwith_submenu addItem:item];

        // and put this stuff into root-level menu
        NSMenuItem *openwith = [NSMenuItem new];
        openwith.title = NSLocalizedStringFromTable(@"Open With", @"FilePanelsContextMenu", "Submenu title to choose app to open with, for English is 'Open With'");
        openwith.submenu = openwith_submenu;
        openwith.keyEquivalent = @"";
        [self addItem:openwith];
        
        NSMenuItem *always_openwith = [NSMenuItem new];
        always_openwith.title = NSLocalizedStringFromTable(@"Always Open With", @"FilePanelsContextMenu", "Submenu title to choose app to always open with, for English is 'Always Open With'");
        always_openwith.submenu = always_openwith_submenu;
        always_openwith.alternate = true;
        always_openwith.keyEquivalent = @"";
        always_openwith.keyEquivalentModifierMask = NSAlternateKeyMask;
        [self addItem:always_openwith];
        
        [self addItem:NSMenuItem.separatorItem];
    }

    //////////////////////////////////////////////////////////////////////
    // Move to Trash / Delete Permanently stuff
    const auto trash_item = [NSMenuItem new];
    trash_item.title = NSLocalizedStringFromTable(@"Move to Trash", @"FilePanelsContextMenu", "Menu item title to move to trash, for English is 'Move to Trash'");
    trash_item.target = self;
    trash_item.action = @selector(OnMoveToTrash:);
    trash_item.hidden = !m_MoveToTrashAction->Predicate(m_Panel);
    trash_item.keyEquivalent = @"";
    [self addItem:trash_item];
    
    const auto delete_item = [NSMenuItem new];
    delete_item.title = NSLocalizedStringFromTable(@"Delete Permanently", @"FilePanelsContextMenu", "Menu item title to delete file, for English is 'Delete Permanently'");
    delete_item.target = self;
    delete_item.action = @selector(OnDeletePermanently:);
    delete_item.alternate = trash_item.hidden ? false : true;
    delete_item.keyEquivalent = @"";
    delete_item.keyEquivalentModifierMask = trash_item.hidden ? 0 : NSAlternateKeyMask;
    [self addItem:delete_item];

    [self addItem:NSMenuItem.separatorItem];
    
    
    //////////////////////////////////////////////////////////////////////
    // Compression stuff
    const auto compression_enabled = ActivationManager::Instance().HasCompressionOperation();
   
    const auto compress_here_item = [NSMenuItem new];
    compress_here_item.title = NSLocalizedStringFromTable(@"Compress", @"FilePanelsContextMenu", "Compress some items here");
    compress_here_item.target = self;
    compress_here_item.action = compression_enabled ? @selector(OnCompressToCurrentPanel:) : nil;
    compress_here_item.keyEquivalent = @"";
    [self addItem:compress_here_item];
    
    const auto compress_in_opposite_item = [NSMenuItem new];
    compress_in_opposite_item.title = NSLocalizedStringFromTable(@"Compress in Opposite Panel", @"FilePanelsContextMenu", "Compress some items");
    compress_in_opposite_item.target = self;
    compress_in_opposite_item.action = compression_enabled ? @selector(OnCompressToOppositePanel:) : nil;
    compress_in_opposite_item.keyEquivalent = @"";
    compress_in_opposite_item.alternate = YES;
    compress_in_opposite_item.keyEquivalentModifierMask = NSAlternateKeyMask;
    [self addItem:compress_in_opposite_item];
    
    //////////////////////////////////////////////////////////////////////
    // Duplicate stuff
    const auto duplicate_item = [NSMenuItem new];
    duplicate_item.title = NSLocalizedStringFromTable(@"Duplicate", @"FilePanelsContextMenu", "Duplicate an item");
    duplicate_item.target = self;
    duplicate_item.action = @selector(OnDuplicateItem:);
    [self addItem:duplicate_item];
    
    //////////////////////////////////////////////////////////////////////
    // Share stuff
    {
        NSMenu *share_submenu = [NSMenu new];
        bool eligible = m_CommonHost && m_CommonHost->IsNativeFS();
        if(eligible) {
            m_ShareItemsURLs = [NSMutableArray new];
            for( auto &i:m_Items )
                if( NSString *s = [NSString stringWithUTF8StdString:i.Path()] )
                    if( NSURL *url = [[NSURL alloc] initFileURLWithPath:s] )
                        [m_ShareItemsURLs addObject:url];
            
            NSArray *sharingServices = [NSSharingService sharingServicesForItems:m_ShareItemsURLs];
            if (sharingServices.count > 0)
                for (NSSharingService *currentService in sharingServices) {
                    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:currentService.title
                                                                  action:@selector(OnShareWithService:)
                                                           keyEquivalent:@""];
                    item.image = currentService.image;
                    item.representedObject = currentService;
                    item.target = self;
                    [share_submenu addItem:item];
                }
            else
                eligible = false;
        }
        
        NSMenuItem *share_menuitem = [NSMenuItem new];
        share_menuitem.title = NSLocalizedStringFromTable(@"Share", @"FilePanelsContextMenu", "Share submenu title");
        share_menuitem.submenu = share_submenu;
        share_menuitem.enabled = eligible;
        [self addItem:share_menuitem];
    }
    
    [self addItem:NSMenuItem.separatorItem];
    
    //////////////////////////////////////////////////////////////////////
    // Copy element for native FS. simply copies selected items' paths
    {
        NSMenuItem *item = [NSMenuItem new];
        item.target = self;
        item.action = @selector(OnCopyPaths:);
        [self addItem:item];
    }

    [self addItem:NSMenuItem.separatorItem];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    if( item.action == @selector(OnCopyPaths:) )
        return m_CopyAction->ValidateMenuItem(m_Panel, item);
    if( item.action == @selector(OnMoveToTrash:) )
        return m_MoveToTrashAction->ValidateMenuItem(m_Panel, item);
    if( item.action == @selector(OnDeletePermanently:) )
        return m_DeletePermanentlyAction->ValidateMenuItem(m_Panel, item);
    if( item.action == @selector(OnDuplicateItem:) )
        return m_DuplicateAction->ValidateMenuItem(m_Panel, item);
    if( item.action == @selector(OnCompressToCurrentPanel:) )
        return m_CompressHereAction->ValidateMenuItem(m_Panel, item);
    if( item.action == @selector(OnCompressToOppositePanel:) )
        return m_CompressToOppositeAction->ValidateMenuItem(m_Panel, item);
    return true;
}

- (void)OnRegularOpen:(id)sender
{
    [self OpenItemsWithApp:"" bundle_id:nil];
}

- (void)OnOpenWith:(id)sender
{
    int app_no = (int)[sender tag];
    assert(app_no >= 0 && app_no < m_OpenWithHandlers.size());
    [self OpenItemsWithApp:m_OpenWithHandlers[app_no].path bundle_id:m_OpenWithHandlers[app_no].app_id];
}

- (void)OnAlwaysOpenWith:(id)sender
{
    int app_no = (int)[sender tag];
    assert(app_no >= 0 && app_no < m_OpenWithHandlers.size());
    [self OpenItemsWithApp:m_OpenWithHandlers[app_no].path bundle_id:m_OpenWithHandlers[app_no].app_id];
    
    if(!m_ItemsUTI.empty())
        LauchServicesHandlers::SetDefaultHandler(m_ItemsUTI, m_OpenWithHandlers[app_no].path);
}

- (void) OpenItemsWithApp:(string)_app_path bundle_id:(NSString*)_app_id
{
    if(m_Items.size() > 1) {
        if( m_CommonHost ) {
            vector<string> items;
            for(auto &i: m_Items)
                items.emplace_back( i.Path() );
            PanelVFSFileWorkspaceOpener::Open(items, m_CommonHost, _app_id, m_Panel);
        }
    }
    else if(m_Items.size() == 1)
        PanelVFSFileWorkspaceOpener::Open(m_Items.front().Path(), m_Items.front().Host(), _app_path, m_Panel);
}

- (void)OnOpenWithOther:(id)sender
{
    ShowOpenPanel( BuildAppChoose(), m_Panel.window, [=](auto _path){
        OpenWithHandler hndl;
        if( ExposeOpenWithHandler(_path, hndl) )
            [self OpenItemsWithApp:hndl.path bundle_id:hndl.app_id];
    });
}

- (void)OnAlwaysOpenWithOther:(id)sender
{
    ShowOpenPanel( BuildAppChoose(), m_Panel.window, [=](auto _path){
        if( !m_ItemsUTI.empty() )
            LauchServicesHandlers::SetDefaultHandler(m_ItemsUTI, _path);
        
        OpenWithHandler hndl;
        if(ExposeOpenWithHandler(_path, hndl))
            [self OpenItemsWithApp:hndl.path bundle_id:hndl.app_id];
    });
}

- (void)OnMoveToTrash:(id)sender
{
    m_MoveToTrashAction->Perform(m_Panel, sender);
}

- (void)OnDeletePermanently:(id)sender
{
    m_DeletePermanentlyAction->Perform(m_Panel, sender);
}

- (void)OnCopyPaths:(id)sender
{
    m_CopyAction->Perform(m_Panel, sender);
}

- (void)OnCompressToOppositePanel:(id)sender
{
    m_CompressToOppositeAction->Perform(m_Panel, sender);
}

- (void)OnCompressToCurrentPanel:(id)sender
{
    m_CompressHereAction->Perform(m_Panel, sender);
}

- (void)OnShareWithService:(id)sender
{
    NSSharingService *service = ((NSMenuItem*)sender).representedObject;
    [service performWithItems:m_ShareItemsURLs];
}

- (void)OnDuplicateItem:(id)sender
{
    m_DuplicateAction->Perform(m_Panel, sender);
}

@end
