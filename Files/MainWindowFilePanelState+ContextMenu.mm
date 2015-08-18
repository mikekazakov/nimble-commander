//
//  MainWindowFilePanelState+ContextMenu.m
//  Files
//
//  Created by Michael G. Kazakov on 07.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/stat.h>
#import <Sparkle/Sparkle.h>
#import "MainWindowFilePanelState+ContextMenu.h"
#import "Common.h"
#import "sysinfo.h"
#import "PanelAux.h"
#import "LSUrls.h"
#import "FileDeletionOperation.h"
#import "PanelController.h"
#import "FileCompressOperation.h"
#import "FileCopyOperation.h"

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

@interface MainWindowFilePanelContextMenu : NSMenu<NSMenuDelegate>

- (id) initWithData:(const vector<const VFSListingItem*>&) _items
             OnPath:(const char*)_path
                vfs:(shared_ptr<VFSHost>) _host
            mainWnd:(MainWindowFilePanelState*)_wnd
             myCont:(PanelController*)_my_cont
            oppCont:(PanelController*)_opp_cont;

@end

@implementation MainWindowFilePanelContextMenu
{
    string                 m_DirPath;
    shared_ptr<VFSHost>    m_Host;
    vector<string>    m_Items;
    vector<OpenWithHandler> m_OpenWithHandlers;
    string                 m_ItemsUTI;
    MainWindowFilePanelState    *m_MainWnd;
    PanelController             *m_CurrentController;
    PanelController             *m_OppositeController;
    NSMutableArray              *m_ShareItemsURLs;
    
    int                         m_DirsCount;
    int                         m_FilesCount;
}

- (id) initWithData:(const vector<const VFSListingItem*>&) _items
             OnPath:(const char*)_path
                vfs:(shared_ptr<VFSHost>) _host
            mainWnd:(MainWindowFilePanelState*)_wnd
             myCont:(PanelController*)_my_cont
            oppCont:(PanelController*)_opp_cont
{
    self = [super init];
    if(self)
    {
        assert(IsPathWithTrailingSlash(_path));
        assert(!_items.empty());
        m_Host = _host;
        m_DirPath = _path;
        m_MainWnd = _wnd;
        m_CurrentController = _my_cont;
        m_OppositeController = _opp_cont;
        m_DirsCount = m_FilesCount = 0;
        self.delegate = self;
        
        for(auto &i: _items)
        {
            m_Items.push_back(i->Name());
            
            if(i->IsDir()) m_DirsCount++;
            if(i->IsReg()) m_FilesCount++;
        }
    
        [self setMinimumWidth:200]; // hardcoding is bad!
        [self Stuffing:_items];
    
        
    }
    return self;
}

- (void) Stuffing:(const vector<const VFSListingItem*>&) _items
{
    // cur_pnl_path should be the same as m_DirPath!!!
    string cur_pnl_path = m_CurrentController.currentDirectoryPath;
    string opp_pnl_path = m_OppositeController.currentDirectoryPath;
    bool cur_pnl_native = m_CurrentController.vfs->IsNativeFS();
    bool cur_pnl_writable = m_CurrentController.vfs->IsWriteableAtPath(cur_pnl_path.c_str());
    bool opp_pnl_writable = m_OppositeController.vfs->IsWriteableAtPath(opp_pnl_path.c_str());
    
    //////////////////////////////////////////////////////////////////////
    // regular Open item
    if(m_FilesCount > 0 || m_Host->IsNativeFS())
    {
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
        for(auto &i: _items)
        {
            char full_path[MAXPATHLEN];
            sprintf(full_path, "%s%s", m_DirPath.c_str(), i->Name());
            auto lsh = LauchServicesHandlers::GetForItem(*i, m_Host, full_path);
            per_item_handlers.emplace_back(move(lsh));
            
            // check if there is no need to investigate types further since there's already no intersection
            LauchServicesHandlers items_check;
            LauchServicesHandlers::DoMerge(per_item_handlers, items_check);
            if(items_check.paths.empty() && items_check.uti.empty())
                break;
        }
        
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
            if(m_OpenWithHandlers[i].is_default)
            {
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
        for(int i = 0; i < m_OpenWithHandlers.size(); ++i)
            if(!m_OpenWithHandlers[i].is_default)
            {
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
                          [NSString stringWithUTF8StdStringNoCopy:m_Items[0]]];
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
                          [NSString stringWithUTF8StdStringNoCopy:m_Items[0]]];
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
        if(m_Items.size() == 1 && cur_pnl_writable) {
            item.target = self;
            item.action = @selector(OnDuplicateItem:);
        }
        [self addItem:item];
    }
    
    //////////////////////////////////////////////////////////////////////
    // Share stuff
    {
        NSMenu *share_submenu = [NSMenu new];
        bool eligible = m_Host->IsNativeFS();
        if(eligible)
        {
            m_ShareItemsURLs = [NSMutableArray new];
            for(auto &i:m_Items) {
                char path[MAXPATHLEN];
                strcpy(path, m_DirPath.c_str());
                strcat(path, i.c_str());
                if(NSString *s = [NSString stringWithUTF8String:path])
                    if(NSURL *url = [[NSURL alloc] initFileURLWithPath:s])
                        [m_ShareItemsURLs addObject:url];
            }
            
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
                          [NSString stringWithUTF8StdStringNoCopy:m_Items[0]]];
        if(m_Host->IsNativeFS()) {  // such thing works only on native file systems
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
        LauchServicesHandlers::SetDefaultHandler(m_ItemsUTI.c_str(), m_OpenWithHandlers[app_no].path.c_str());
}

- (void) OpenItemsWithApp:(string)_app_path bundle_id:(NSString*)_app_id
{
    if(m_Items.size() > 1)
    {
        vector<string> items;
        for(auto &i: m_Items)
            items.push_back(m_DirPath + i);
            
        PanelVFSFileWorkspaceOpener::Open(items, m_Host, _app_id);
    }
    else if(m_Items.size() == 1)
        PanelVFSFileWorkspaceOpener::Open(m_DirPath + m_Items.front(), m_Host, _app_path);
}

- (NSOpenPanel*) BuildAppChoose
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setDirectoryURL:[[NSURL alloc] initFileURLWithPath:@"/Applications" isDirectory:true]];
    [panel setAllowedFileTypes:[NSArray arrayWithObject:@"app"]];
    return panel;
}

- (void)OnOpenWithOther:(id)sender
{
    NSOpenPanel *panel = [self BuildAppChoose];
    [panel beginSheetModalForWindow:m_MainWnd.windowContentView.window
                  completionHandler:^(NSInteger result){
                      if(result == NSFileHandlingPanelOKButton)
                      {
                          OpenWithHandler hndl;
                          if(ExposeOpenWithHandler(panel.URL.path.fileSystemRepresentation, hndl))
                              [self OpenItemsWithApp:hndl.path bundle_id:hndl.app_id];
                      }
                  }];
}

- (void)OnAlwaysOpenWithOther:(id)sender
{
    NSOpenPanel *panel = [self BuildAppChoose];
    [panel beginSheetModalForWindow:m_MainWnd.windowContentView.window
                  completionHandler:^(NSInteger result){
                      if(result == NSFileHandlingPanelOKButton)
                      {
                          if(!m_ItemsUTI.empty())
                              LauchServicesHandlers::SetDefaultHandler(m_ItemsUTI.c_str(), panel.URL.path.fileSystemRepresentation);
                          
                          OpenWithHandler hndl;
                          if(ExposeOpenWithHandler(panel.URL.path.fileSystemRepresentation, hndl))
                              [self OpenItemsWithApp:hndl.path bundle_id:hndl.app_id];
                      }
                  }];
}

- (void)OnMoveToTrash:(id)sender
{
    assert(m_CurrentController.vfs->IsNativeFS());
    FileDeletionOperation *op = [[FileDeletionOperation alloc]
                                 initWithFiles:vector<string>(m_Items)
                                 type:FileDeletionOperationType::MoveToTrash
                                 dir:m_DirPath];
    [m_MainWnd AddOperation:op];
}

- (void)OnDeletePermanently:(id)sender
{
    FileDeletionOperation *op = [FileDeletionOperation alloc];
    if(m_CurrentController.vfs->IsNativeFS())
        op = [op initWithFiles:vector<string>(m_Items)
                          type:FileDeletionOperationType::Delete
                           dir:m_DirPath];
    else
        op = [op initWithFiles:vector<string>(m_Items)
                           dir:m_DirPath
                            at:m_CurrentController.vfs];

    [m_MainWnd AddOperation:op];
}

- (void)OnCopyPaths:(id)sender
{
    NSMutableArray *filenames = [[NSMutableArray alloc] initWithCapacity:m_Items.size()];
    
    for(auto &i: m_Items)
        [filenames addObject:[NSString stringWithUTF8String:(m_DirPath + i).c_str()]];
    
    NSPasteboard *pasteBoard = NSPasteboard.generalPasteboard;
    [pasteBoard clearContents];
    [pasteBoard declareTypes:@[NSFilenamesPboardType] owner:nil];
    [pasteBoard setPropertyList:filenames forType:NSFilenamesPboardType];
}

- (void)OnCompressToOppositePanel:(id)sender
{
    FileCompressOperation* op = [[FileCompressOperation alloc] initWithFiles:vector<string>(m_Items)
                                                                     srcroot:m_DirPath
                                                                      srcvfs:m_CurrentController.vfs
                                                                     dstroot:m_OppositeController.currentDirectoryPath
                                                                      dstvfs:m_OppositeController.vfs
                                 ];
    op.TargetPanel = m_OppositeController;
    [m_MainWnd AddOperation:op];
}

- (void)OnCompressToCurrentPanel:(id)sender
{
    FileCompressOperation* op = [[FileCompressOperation alloc] initWithFiles:vector<string>(m_Items)
                                                                     srcroot:m_DirPath
                                                                      srcvfs:m_CurrentController.vfs
                                                                     dstroot:m_DirPath
                                                                      dstvfs:m_CurrentController.vfs
                                 ];
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
    char filename[MAXPATHLEN], ext[MAXPATHLEN];
    bool has_ext = false;
    {
        const char *orig = m_Items[0].c_str();
        char *last_dot = strrchr(orig, '.');
        if(last_dot == 0) {
            strcpy(filename, orig);
        }
        else
        {
            if(last_dot == orig || last_dot == orig + strlen(orig) - 1) {
                strcpy(filename, orig);
            }
            else {
                memcpy(filename, orig, last_dot - orig);
                filename[last_dot - orig] = 0;
                strcpy(ext, last_dot+1);
                has_ext = true;
            }
        }
    }
    
    char target[MAXPATHLEN];
    sprintf(target, "%s%s copy", m_DirPath.c_str(), filename);
    if(has_ext) {
        strcat(target, ".");
        strcat(target, ext);
    }
    
    VFSStat st;
    if(m_Host->Stat(target, st, VFSFlags::F_NoFollow, 0) == 0)
    { // this file already exists, will try another ones
        for(int i = 2; i < 100; ++i) {
            sprintf(target, "%s%s copy %d", m_DirPath.c_str(), filename, i);
            if(has_ext) {
                strcat(target, ".");
                strcat(target, ext);
            }
            if(m_Host->Stat(target, st, VFSFlags::F_NoFollow, 0) != 0)
                goto proceed;
            
        }
        return; // we're full of such filenames, no reason to go on
    }
    
proceed:;
    FileCopyOperationOptions opts;
    opts.docopy = true;
    
    FileCopyOperation *op = [FileCopyOperation alloc];
    if(m_CurrentController.vfs->IsNativeFS())
        op = [op initWithFiles:vector<string>(1, m_Items[0])
                          root:m_DirPath.c_str()
                          dest:target
                       options:opts];
    else
        op = [op initWithFiles:vector<string>(1, m_Items[0])
                          root:m_DirPath.c_str()
                        srcvfs:m_CurrentController.vfs
                          dest:target
                        dstvfs:m_CurrentController.vfs
                       options:opts];
    
    char target_fn[MAXPATHLEN];
    GetFilenameFromPath(target, target_fn);
    string target_fns = target_fn;
    string current_pan_path = m_CurrentController.currentDirectoryPath;
    [op AddOnFinishHandler:^{
        if(m_CurrentController.currentDirectoryPath == current_pan_path)
            dispatch_to_main_queue( [=]{
                PanelControllerDelayedSelection req;
                req.filename = target_fns;
                [m_CurrentController ScheduleDelayedSelectionChangeFor:req];
            });
        }
     ];
    
    [m_MainWnd AddOperation:op];
}

@end


@implementation MainWindowFilePanelState (ContextMenu)

- (NSMenu*) RequestContextMenuOn:(const vector<const VFSListingItem*>&) _items
                         path:(const char*) _path
                          vfs:(shared_ptr<VFSHost>) _host
                       caller:(PanelController*) _caller
{
    PanelController *current_cont = _caller;
    PanelController *opp_cont;
    if(current_cont == self.leftPanelController)
        opp_cont = self.rightPanelController;
    else if(current_cont == self.rightPanelController)
        opp_cont = self.leftPanelController;
    else
        return nil;
    
    MainWindowFilePanelContextMenu *menu = [MainWindowFilePanelContextMenu alloc];
    menu = [menu initWithData:_items
                       OnPath:_path
                          vfs:_host
                      mainWnd:self
                       myCont:current_cont
                      oppCont:opp_cont];

    return menu;
}

@end
