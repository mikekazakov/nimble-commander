//
//  MainWindowFilePanelState+ContextMenu.m
//  Files
//
//  Created by Michael G. Kazakov on 07.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <sys/stat.h>
#include <Sparkle/Sparkle.h>
#include "MainWindowFilePanelState+ContextMenu.h"
#include "Common.h"
#include "sysinfo.h"
#include "PanelAux.h"
#include "LSUrls.h"
#include "Operations/Delete/FileDeletionOperation.h"
#include "PanelController.h"
#include "FileCompressOperation.h"
#include "Operations/Copy/FileCopyOperation.h"

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

static inline chained_strings StringsFromVector(const vector<string> &_files)
{
    chained_strings files;
    for(auto &i:_files)
        files.push_back(i.c_str(), (int)i.length(), nullptr);
    return files;
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

static string FindFreeFilenameToDuplicateIn(const VFSListingItem& _item)
{
    string filename = _item.FilenameWithoutExt();
    string ext = _item.HasExtension() ? "."s + _item.Extension() : ""s;
    string target = _item.Directory() + filename + " copy" + ext;
    
    VFSStat st;
    if( _item.Host()->Stat(target.c_str(), st, VFSFlags::F_NoFollow, 0) == 0 ) {
        // this file already exists, will try another ones
        for(int i = 2; i < 100; ++i) {
            target = _item.Directory() + filename + " copy " + to_string(i) + ext;
            if( _item.Host()->Stat(target.c_str(), st, VFSFlags::F_NoFollow, 0) != 0 )
                return target;
    
        }
        return ""; // we're full of such filenames, no reason to go on
    }
    return target;
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

@interface MainWindowFilePanelContextMenu : NSMenu<NSMenuDelegate>
@end

@implementation MainWindowFilePanelContextMenu
{
    string                              m_CommonDir;  // may be "" in case of non-uniform listing
    VFSHostPtr                          m_CommonHost; // may be nullptr in case of non-uniform listing
    vector<VFSListingItem>      m_Items;
    vector<OpenWithHandler>             m_OpenWithHandlers;
    string                              m_ItemsUTI;
    MainWindowFilePanelState           *m_MainWnd;
    PanelController                    *m_CurrentController;
    PanelController                    *m_OppositeController;
    NSMutableArray                     *m_ShareItemsURLs;
    int                                 m_DirsCount;
    int                                 m_FilesCount;
}

- (id) initWithData:(vector<VFSListingItem>) _items
            mainWnd:(MainWindowFilePanelState*)_wnd
             myCont:(PanelController*)_my_cont
            oppCont:(PanelController*)_opp_cont
{
    if( _items.empty() )
        throw invalid_argument("MainWindowFilePanelContextMenu.initWithData - there's no items");
    self = [super init];
    if(self) {
        m_MainWnd = _wnd;
        m_CurrentController = _my_cont;
        m_OppositeController = _opp_cont;
        m_DirsCount = m_FilesCount = 0;
        m_Items = move(_items);
        m_DirsCount = (int)count_if(begin(m_Items), end(m_Items), [](auto &i) { return i.IsDir(); });
        m_FilesCount = (int)count_if(begin(m_Items), end(m_Items), [](auto &i) { return i.IsReg(); });
        m_CommonHost = common_or_default_element( m_Items, VFSHostPtr{}, [](auto &_) -> const VFSHostPtr& { return _.Host(); } );
        m_CommonDir = common_or_default_element( m_Items, ""s, [](auto &_) -> const string& { return _.Directory(); } );

        self.delegate = self;
        self.minimumWidth = 200; // hardcoding is bad!
    

        [self doStuffing];
    }
    return self;
}

- (void) doStuffing
{
    bool cur_pnl_native = m_CommonHost && m_CommonHost->IsNativeFS();
    bool cur_pnl_writable = true;
    if( m_CurrentController.isUniform  )
        cur_pnl_writable = m_CurrentController.vfs->IsWriteableAtPath( m_CurrentController.currentDirectoryPath.c_str() );
    bool opp_pnl_writable = true;
    if( m_OppositeController.isUniform )
        opp_pnl_writable = m_OppositeController.vfs->IsWriteableAtPath( m_OppositeController.currentDirectoryPath.c_str() );
    
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
    {
        NSMenuItem *item;
        if(cur_pnl_native) {
            item = [NSMenuItem new];
            item.title = NSLocalizedStringFromTable(@"Move to Trash", @"FilePanelsContextMenu", "Menu item title to move to trash, for English is 'Move to Trash'");
            if(cur_pnl_writable) { // gray out this thing on read-only fs
                item.target = self;
                item.action = @selector(OnMoveToTrash:);
            }
            item.keyEquivalent = @"";
            [self addItem:item];
        }
        
        item = [NSMenuItem new];
        item.title = NSLocalizedStringFromTable(@"Delete Permanently", @"FilePanelsContextMenu", "Menu item title to delete file, for English is 'Delete Permanently'");
        if(cur_pnl_writable) { // gray out this thing on read-only fs
            item.target = self;
            item.action = @selector(OnDeletePermanently:);
        }
        item.alternate = cur_pnl_native ? true : false;
        item.keyEquivalent = @"";
        item.keyEquivalentModifierMask = cur_pnl_native ? NSAlternateKeyMask : 0;
        [self addItem:item];
    }
    [self addItem:NSMenuItem.separatorItem];
    
    
    //////////////////////////////////////////////////////////////////////
    // Compression stuff
    if(configuration::has_compression_operation)
    {
        NSMenuItem *item = [NSMenuItem new];
        if(m_Items.size() > 1)
            item.title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compress %lu Items", @"FilePanelsContextMenu", "Compress some items"),
                          m_Items.size()];
        else
            item.title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compress \u201c%@\u201d", @"FilePanelsContextMenu", "Compress one item"),
                          [NSString stringWithUTF8StdString:m_Items.front().Filename()]];
        if(opp_pnl_writable) { // gray out this thing if we can't compress on opposite panel
            item.target = self;
            item.action = @selector(OnCompressToOppositePanel:);
        }
        item.keyEquivalent = @"";
        [self addItem:item];
        
        item = [NSMenuItem new];
        if(m_Items.size() > 1)
            item.title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compress %lu Items Here", @"FilePanelsContextMenu", "Compress some items here"),
                          m_Items.size()];
        else
            item.title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compress \u201c%@\u201d Here", @"FilePanelsContextMenu", "Compress one item here"),
                          [NSString stringWithUTF8StdString:m_Items.front().Filename()]];
        if(cur_pnl_writable) { // gray out this thing if we can't compress on this panel
            item.target = self;
            item.action = @selector(OnCompressToCurrentPanel:);
        }
        item.keyEquivalent = @"";
        item.alternate = YES;
        item.keyEquivalentModifierMask = NSAlternateKeyMask;
        [self addItem:item];
    }

    //////////////////////////////////////////////////////////////////////
    // Duplicate stuff
    {
        NSMenuItem *item = [NSMenuItem new];
        item.title = NSLocalizedStringFromTable(@"Duplicate", @"FilePanelsContextMenu", "Duplicate an item");
        if( m_Items.size() == 1 && cur_pnl_writable ) {
            item.target = self;
            item.action = @selector(OnDuplicateItem:);
        }
        [self addItem:item];
    }
    
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
    
    [self addItem:[NSMenuItem separatorItem]];
    
    //////////////////////////////////////////////////////////////////////
    // Copy element for native FS. simply copies selected items' paths
    {
        NSMenuItem *item = [NSMenuItem new];
        if(m_Items.size() > 1)
            item.title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Copy %lu Items", @"FilePanelsContextMenu", "Copy many items"),
                          m_Items.size()];
        else
            item.title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Copy \u201c%@\u201d", @"FilePanelsContextMenu", "Copy one item"),
                          [NSString stringWithUTF8StdString:m_Items.front().Filename()]];
        if( m_CommonHost && m_CommonHost->IsNativeFS() ) {  // such thing works only on native file systems
            item.target = self;
            item.action = @selector(OnCopyPaths:);
        }
        [self addItem:item];
    }

    [self addItem:NSMenuItem.separatorItem];
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
            PanelVFSFileWorkspaceOpener::Open(items, m_CommonHost, _app_id);
        }
    }
    else if(m_Items.size() == 1)
        PanelVFSFileWorkspaceOpener::Open(m_Items.front().Path(), m_Items.front().Host(), _app_path);
}

- (void)OnOpenWithOther:(id)sender
{
    ShowOpenPanel( BuildAppChoose(), m_MainWnd.windowContentView.window, [=](auto _path){
        OpenWithHandler hndl;
        if( ExposeOpenWithHandler(_path, hndl) )
            [self OpenItemsWithApp:hndl.path bundle_id:hndl.app_id];
    });
}

- (void)OnAlwaysOpenWithOther:(id)sender
{
    ShowOpenPanel( BuildAppChoose(), m_MainWnd.windowContentView.window, [=](auto _path){
        if( !m_ItemsUTI.empty() )
            LauchServicesHandlers::SetDefaultHandler(m_ItemsUTI, _path);
        
        OpenWithHandler hndl;
        if(ExposeOpenWithHandler(_path, hndl))
            [self OpenItemsWithApp:hndl.path bundle_id:hndl.app_id];
    });
}

- (void)OnMoveToTrash:(id)sender
{
    // TODO: rewrite
    if( m_CommonHost && !m_CommonDir.empty() ) {
        vector<string> filenames;
        for(auto &i: m_Items)
            filenames.emplace_back( i.Filename() );
        
        FileDeletionOperation *op = [[FileDeletionOperation alloc]
                                     initWithFiles:move(filenames)
                                     type:FileDeletionOperationType::MoveToTrash
                                     dir:m_CommonDir];
        [m_MainWnd AddOperation:op];
    }
}

- (void)OnDeletePermanently:(id)sender
{
    // TODO: rewrite
    if( m_CommonHost && !m_CommonDir.empty() ) {
        vector<string> filenames;
        for(auto &i: m_Items)
            filenames.emplace_back( i.Filename() );
        
        FileDeletionOperation *op = [FileDeletionOperation alloc];
        if(m_CommonHost->IsNativeFS())
            op = [op initWithFiles:move(filenames)
                              type:FileDeletionOperationType::Delete
                               dir:m_CommonDir];
        else
            op = [op initWithFiles:move(filenames)
                               dir:m_CommonDir
                                at:m_CommonHost];
        
        [m_MainWnd AddOperation:op];
    }
}

- (void)OnCopyPaths:(id)sender
{
    NSMutableArray *filenames = [[NSMutableArray alloc] initWithCapacity:m_Items.size()];
    
    for(auto &i: m_Items)
        if(i.Host()->IsNativeFS())
            [filenames addObject:[NSString stringWithUTF8StdString:i.Path()]];
    
    NSPasteboard *pasteBoard = NSPasteboard.generalPasteboard;
    [pasteBoard clearContents];
    [pasteBoard declareTypes:@[NSFilenamesPboardType] owner:nil];
    [pasteBoard setPropertyList:filenames forType:NSFilenamesPboardType];
}

- (void)OnCompressToOppositePanel:(id)sender
{
    if( !m_OppositeController.isUniform )
        return;
    auto op = [[FileCompressOperation alloc] initWithFiles:m_Items
                                                   dstroot:m_OppositeController.currentDirectoryPath
                                                    dstvfs:m_OppositeController.vfs];
    op.TargetPanel = m_OppositeController;
    [m_MainWnd AddOperation:op];
}

- (void)OnCompressToCurrentPanel:(id)sender
{
    if( !m_CommonHost || m_CommonDir.empty() )
        return;
    auto op = [[FileCompressOperation alloc] initWithFiles:m_Items
                                                   dstroot:m_CommonDir
                                                    dstvfs:m_CommonHost];
    op.TargetPanel = m_CurrentController;
    [m_MainWnd AddOperation:op];
}

- (void)OnShareWithService:(id)sender
{
    NSSharingService *service = ((NSMenuItem*)sender).representedObject;
    [service performWithItems:m_ShareItemsURLs];
}

- (void)OnDuplicateItem:(id)sender
{
    // currently duplicating only first file in a selected set
    auto &item = m_Items.front();
    if( !item.Host()->IsWriteable() )
        return;
    
    auto target = FindFreeFilenameToDuplicateIn(item);
    if( target.empty() )
        return;

    FileCopyOperationOptions opts;
    opts.docopy = true;
    
    auto op = [[FileCopyOperation alloc] initWithItems:{item} destinationPath:target destinationHost:item.Host() options:opts];
    
    auto filename = target.substr( target.find_last_of('/') + 1 );
    [op AddOnFinishHandler:^{
        dispatch_to_main_queue( [=]{
            PanelControllerDelayedSelection req;
            req.filename = filename;
            [m_CurrentController ScheduleDelayedSelectionChangeFor:req];
        });
      }
     ];
    [m_MainWnd AddOperation:op];
}

@end


@implementation MainWindowFilePanelState (ContextMenu)

- (NSMenu*) RequestContextMenuOn:(vector<VFSListingItem>) _items
                          caller:(PanelController*) _caller
{
    if( _items.empty() )
        return nil;
    
    PanelController *current_cont = _caller;
    PanelController *opp_cont;
    if(current_cont == self.leftPanelController)
        opp_cont = self.rightPanelController;
    else if(current_cont == self.rightPanelController)
        opp_cont = self.leftPanelController;
    else
        return nil;
    
    MainWindowFilePanelContextMenu *menu = [MainWindowFilePanelContextMenu alloc];
    menu = [menu initWithData:move(_items)
                      mainWnd:self
                       myCont:current_cont
                      oppCont:opp_cont];

    return menu;
}

@end
