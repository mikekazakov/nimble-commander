//
//  MainWindowFilePanelState+ContextMenu.m
//  Files
//
//  Created by Michael G. Kazakov on 07.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "3rd_party/sparkle/SUStandardVersionComparator.h"
#import "MainWindowFilePanelState+ContextMenu.h"
#import "Common.h"
#import "PanelAux.h"
#import "LSUrls.h"
#import "FileDeletionOperation.h"
#import "PanelController.h"
#import "FileCompressOperation.h"

struct OpenWithHandler
{
    std::string path;
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

static bool ExposeOpenWithHandler(const std::string &_path, OpenWithHandler &_hndl)
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

static inline FlexChainedStringsChunk *StringsFromVector(const std::vector<std::string> &_files)
{
    FlexChainedStringsChunk *files = FlexChainedStringsChunk::Allocate(), *files_it = files;
    for(auto &i:_files)
        files_it = files_it->AddString(i.c_str(), (int)i.length(), 0);
    return files;
}

static void PurgeDuplicateHandlers(std::vector<OpenWithHandler> &_handlers)
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

@interface MainWindowFilePanelContextMenu : NSMenu


- (id) initWithData:(const std::vector<const VFSListingItem*>&) _items
             OnPath:(const char*)_path
                vfs:(std::shared_ptr<VFSHost>) _host
                pos:(NSPoint)_pos
             inView:(NSView*)_in_view
            mainWnd:(MainWindowFilePanelState*)_wnd
             myCont:(PanelController*)_my_cont
            oppCont:(PanelController*)_opp_cont;

- (void) PopUp;

@end

@implementation MainWindowFilePanelContextMenu
{
    std::string                 m_DirPath;
    std::shared_ptr<VFSHost>    m_Host;
    NSPoint                     m_Pos;
    NSView                     *m_InView;
    std::vector<std::string>    m_Items;
    std::vector<OpenWithHandler> m_OpenWithHandlers;
    std::string                 m_ItemsUTI;
    MainWindowFilePanelState    *m_MainWnd;
    PanelController             *m_CurrentController;
    PanelController             *m_OppositeController;

    
    int                         m_DirsCount;
    int                         m_FilesCount;
}

- (id) initWithData:(const std::vector<const VFSListingItem*>&) _items
             OnPath:(const char*)_path
                vfs:(std::shared_ptr<VFSHost>) _host
                pos:(NSPoint)_pos
             inView:(NSView*)_in_view
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
        m_Pos = _pos;
        m_InView = _in_view;
        m_MainWnd = _wnd;
        m_CurrentController = _my_cont;
        m_OppositeController = _opp_cont;
        m_DirsCount = m_FilesCount = 0;
        
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

- (void) Stuffing:(const std::vector<const VFSListingItem*>&) _items
{
    // cur_pnl_path should be the same as m_DirPath!!!
    char cur_pnl_path[MAXPATHLEN], opp_pnl_path[MAXPATHLEN];
    [m_CurrentController GetCurrentDirectoryPathRelativeToHost:cur_pnl_path];
    [m_OppositeController GetCurrentDirectoryPathRelativeToHost:opp_pnl_path];
    bool cur_pnl_writable = [m_CurrentController GetCurrentVFSHost]->IsWriteableAtPath(cur_pnl_path);
    bool opp_pnl_writable = [m_OppositeController GetCurrentVFSHost]->IsWriteableAtPath(opp_pnl_path);
    
    //////////////////////////////////////////////////////////////////////
    // regular Open item
    if(m_FilesCount > 0 || m_Host->IsNativeFS())
    {
        NSMenuItem *item = [NSMenuItem new];
        [item setTitle:@"Open"];
        [item setTarget:self];
        [item setAction:@selector(OnRegularOpen:)];
        [self addItem:item];
    }

    //////////////////////////////////////////////////////////////////////
    // Open With... stuff
    {
        std::list<LauchServicesHandlers> per_item_handlers;
        for(auto &i: _items)
        {
            per_item_handlers.push_back(LauchServicesHandlers());
            char full_path[MAXPATHLEN];
            sprintf(full_path, "%s%s", m_DirPath.c_str(), i->Name());
            LauchServicesHandlers::DoOnItem(i, m_Host, full_path, &per_item_handlers.back());
            
            // check if there is no need to investigate types further since there's already no intersection
            LauchServicesHandlers items_check;
            LauchServicesHandlers::DoMerge(&per_item_handlers, &items_check);
            if(items_check.paths.empty() && items_check.uti.empty())
                break;
        }
        
        LauchServicesHandlers items_handlers;
        LauchServicesHandlers::DoMerge(&per_item_handlers, &items_handlers);
        
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
        std::sort(m_OpenWithHandlers.begin(), m_OpenWithHandlers.end());
        
        // get rid of duplicates in handlers list
        PurgeDuplicateHandlers(m_OpenWithHandlers);
        
        // show default handler if any
        bool any_handlers_added = false;
        for(int i = 0; i < m_OpenWithHandlers.size(); ++i)
            if(m_OpenWithHandlers[i].is_default)
            {
                NSMenuItem *item = [NSMenuItem new];
                [item setTitle: [NSString stringWithFormat:@"%@ (default)",
                                 m_OpenWithHandlers[i].app_name
                                 ]];
                [item setImage:m_OpenWithHandlers[i].app_icon];
                [item setTag:i];
                [item setTarget:self];
                [item setAction:@selector(OnOpenWith:)];
                [openwith_submenu addItem:item];
                
                item = [item copy];
                [item setAction:@selector(OnAlwaysOpenWith:)];
                [always_openwith_submenu addItem:item];

                [openwith_submenu addItem:[NSMenuItem separatorItem]];
                [always_openwith_submenu addItem:[NSMenuItem separatorItem]];
                any_handlers_added = true;
                break;
            }

        // show other handlers
        for(int i = 0; i < m_OpenWithHandlers.size(); ++i)
            if(!m_OpenWithHandlers[i].is_default)
            {
                NSMenuItem *item = [NSMenuItem new];
                [item setTitle:m_OpenWithHandlers[i].app_name];
                [item setImage:m_OpenWithHandlers[i].app_icon];
                [item setTag:i];
                [item setTarget:self];
                [item setAction:@selector(OnOpenWith:)];
                [openwith_submenu addItem:item];
                
                item = [item copy];
                [item setAction:@selector(OnAlwaysOpenWith:)];
                [always_openwith_submenu addItem:item];
                
                any_handlers_added = true;
            }

        // separate them
        if(!any_handlers_added) {
            [openwith_submenu addItem:[[NSMenuItem alloc] initWithTitle:@"<None>" action:nil keyEquivalent:@""]];
            [always_openwith_submenu addItem:[[NSMenuItem alloc] initWithTitle:@"<None>" action:nil keyEquivalent:@""]];
        }
        [openwith_submenu addItem:[NSMenuItem separatorItem]];
        [always_openwith_submenu addItem:[NSMenuItem separatorItem]];
        
        // let user to select program manually
        NSMenuItem *item = [NSMenuItem new];
        [item setTitle:@"Other..."];
        [item setTarget:self];
        [item setAction:@selector(OnOpenWithOther:)];
        [openwith_submenu addItem:item];
        
        item = [item copy];
        [item setAction:@selector(OnAlwaysOpenWithOther:)];
        [always_openwith_submenu addItem:item];

        // and put this stuff into root-level menu
        NSMenuItem *openwith = [NSMenuItem new];
        [openwith setTitle:@"Open With"];
        [openwith setSubmenu:openwith_submenu];
        [openwith setKeyEquivalent:@""];
        [self addItem:openwith];
        
        NSMenuItem *always_openwith = [NSMenuItem new];
        [always_openwith setTitle:@"Always Open With"];
        [always_openwith setSubmenu:always_openwith_submenu];
        [always_openwith setAlternate:YES];
        [always_openwith setKeyEquivalent:@""];
        [always_openwith setKeyEquivalentModifierMask:NSAlternateKeyMask];
        [self addItem:always_openwith];
        
        [self addItem:[NSMenuItem separatorItem]];
    }

    //////////////////////////////////////////////////////////////////////
    // Move to Trash / Delete Permanently stuff
    {
        NSMenuItem *item = [NSMenuItem new];
        [item setTitle:@"Move to Trash"];
        if(cur_pnl_writable) { // gray out this thing on read-only fs
            [item setTarget:self];
            [item setAction:@selector(OnMoveToTrash:)];
        }
        [item setKeyEquivalent:@""];
        [self addItem:item];
        
        item = [NSMenuItem new];
        [item setTitle:@"Delete Permanently"];
        if(cur_pnl_writable) { // gray out this thing on read-only fs
            [item setTarget:self];
            [item setAction:@selector(OnDeletePermanently:)];
        }
        [item setAlternate:YES];
        [item setKeyEquivalent:@""];
        [item setKeyEquivalentModifierMask:NSAlternateKeyMask];
        [self addItem:item];
    }
    [self addItem:[NSMenuItem separatorItem]];
    
    
    //////////////////////////////////////////////////////////////////////
    // Compression stuff
    {
        NSMenuItem *item = [NSMenuItem new];
        if(m_Items.size() > 1)
            [item setTitle:[NSString stringWithFormat:@"Compress %lu Items", m_Items.size()]];
        else
            [item setTitle:[NSString stringWithFormat:@"Compress \"%@\"", [NSString stringWithUTF8StdStringNoCopy:m_Items[0]]]];
        if(opp_pnl_writable) { // gray out this thing if we can't compress on opposite panel
            [item setTarget:self];
            [item setAction:@selector(OnCompressToOppositePanel:)];
        }
        [item setKeyEquivalent:@""];
        [self addItem:item];
        
        item = [NSMenuItem new];
        if(m_Items.size() > 1)
            [item setTitle:[NSString stringWithFormat:@"Compress %lu Items Here", m_Items.size()]];
        else
            [item setTitle:[NSString stringWithFormat:@"Compress \"%@\" Here", [NSString stringWithUTF8StdStringNoCopy:m_Items[0]]]];
        if(cur_pnl_writable) { // gray out this thing if we can't compress on this panel
            [item setTarget:self];
            [item setAction:@selector(OnCompressToCurrentPanel:)];
        }
        [item setKeyEquivalent:@""];
        [item setAlternate:YES];
        [item setKeyEquivalentModifierMask:NSAlternateKeyMask];
        [self addItem:item];
    }
    
    //////////////////////////////////////////////////////////////////////
    // Copy element for native FS. simply copies selected items' paths
    {
        NSMenuItem *item = [NSMenuItem new];
        if(m_Items.size() > 1)
            [item setTitle:[NSString stringWithFormat:@"Copy %lu Items", m_Items.size()]];
        else
            [item setTitle:[NSString stringWithFormat:@"Copy \"%@\"", [NSString stringWithUTF8StdStringNoCopy:m_Items[0]]]];
        if(m_Host->IsNativeFS()) {  // such thing works only on native file systems
            [item setTarget:self];
            [item setAction:@selector(OnCopyPaths:)];
        }
        [self addItem:item];
    }
    [self addItem:[NSMenuItem separatorItem]];
}

- (void)OnRegularOpen:(id)sender
{
    [self OpenItemsWithApp:0];
}

- (void)OnOpenWith:(id)sender
{
    int app_no = (int)[sender tag];
    assert(app_no >= 0 && app_no < m_OpenWithHandlers.size());
    [self OpenItemsWithApp:m_OpenWithHandlers[app_no].path.c_str()];
}

- (void)OnAlwaysOpenWith:(id)sender
{
    int app_no = (int)[sender tag];
    assert(app_no >= 0 && app_no < m_OpenWithHandlers.size());
    [self OpenItemsWithApp:m_OpenWithHandlers[app_no].path.c_str()];
    
    if(!m_ItemsUTI.empty())
        LauchServicesHandlers::SetDefaultHandler(m_ItemsUTI.c_str(), m_OpenWithHandlers[app_no].path.c_str());
}

- (void) OpenItemsWithApp:(const char*)_app_path
{
    for(auto &i: m_Items) {
        char full_path[MAXPATHLEN];
        sprintf(full_path, "%s%s", m_DirPath.c_str(), i.c_str());
        PanelVFSFileWorkspaceOpener::Open(full_path, m_Host, _app_path);
    }
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
    [panel beginSheetModalForWindow:[m_InView window]
                  completionHandler:^(NSInteger result){
                      if(result == NSFileHandlingPanelOKButton)
                          [self OpenItemsWithApp:[[panel URL]fileSystemRepresentation]];
                  }];
}

- (void)OnAlwaysOpenWithOther:(id)sender
{
    NSOpenPanel *panel = [self BuildAppChoose];
    [panel beginSheetModalForWindow:[m_InView window]
                  completionHandler:^(NSInteger result){
                      if(result == NSFileHandlingPanelOKButton)
                      {
                          [self OpenItemsWithApp:[[panel URL]fileSystemRepresentation]];
                          if(!m_ItemsUTI.empty())
                              LauchServicesHandlers::SetDefaultHandler(m_ItemsUTI.c_str(), [[panel URL]fileSystemRepresentation]);
                      }
                  }];
}

- (void)OnMoveToTrash:(id)sender
{
    // TODO: currently no VFS support in DeletionOperation. should be implemented later, using native FS now
    FileDeletionOperation *op = [[FileDeletionOperation alloc]
                                 initWithFiles:StringsFromVector(m_Items)
                                 type:FileDeletionOperationType::MoveToTrash
                                 rootpath:m_DirPath.c_str()];
    [m_MainWnd AddOperation:op];
}

- (void)OnDeletePermanently:(id)sender
{
    // TODO: currently no VFS support in DeletionOperation. should be implemented later, using native FS now
    FlexChainedStringsChunk *files = FlexChainedStringsChunk::Allocate(), *files_it = files;
    for(auto &i:m_Items)
        files_it = files_it->AddString(i.c_str(), (int)i.length(), 0);
    
    FileDeletionOperation *op = [[FileDeletionOperation alloc]
                                 initWithFiles:files
                                 type:FileDeletionOperationType::Delete
                                 rootpath:m_DirPath.c_str()];
    [m_MainWnd AddOperation:op];
}

- (void)OnCopyPaths:(id)sender
{
    NSMutableArray *filenames = [NSMutableArray new];
    
    char tmp[MAXPATHLEN];
    for(auto &i: m_Items) {
        strcpy(tmp, m_DirPath.c_str());
        strcat(tmp, i.c_str());
        [filenames addObject:[NSString stringWithUTF8String:tmp]];
    }
    
    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    [pasteBoard clearContents];
    [pasteBoard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
    [pasteBoard setPropertyList:filenames forType:NSFilenamesPboardType];
}

- (void)OnCompressToOppositePanel:(id)sender
{
    char dstroot[MAXPATHLEN];
    [m_OppositeController GetCurrentDirectoryPathRelativeToHost:dstroot];
    FileCompressOperation* op = [[FileCompressOperation alloc] initWithFiles:StringsFromVector(m_Items)
                                                                     srcroot:m_DirPath.c_str()
                                                                      srcvfs:[m_CurrentController GetCurrentVFSHost]
                                                                     dstroot:dstroot
                                                                      dstvfs:[m_OppositeController GetCurrentVFSHost]
                                 ];
    op.TargetPanel = m_OppositeController;
    [m_MainWnd AddOperation:op];
}

- (void)OnCompressToCurrentPanel:(id)sender
{
    FileCompressOperation* op = [[FileCompressOperation alloc] initWithFiles:StringsFromVector(m_Items)
                                                                     srcroot:m_DirPath.c_str()
                                                                      srcvfs:[m_CurrentController GetCurrentVFSHost]
                                                                     dstroot:m_DirPath.c_str()
                                                                      dstvfs:[m_CurrentController GetCurrentVFSHost]
                                 ];
    op.TargetPanel = m_CurrentController;
    [m_MainWnd AddOperation:op];
}

- (void) PopUp
{
    // ensure that there will be no vertical scroll
    NSRect vis_frame = [[[m_InView window] screen] visibleFrame];
    NSSize mysize = [self size];
    NSPoint windowPoint = [m_InView convertPoint:m_Pos toView:nil];
    NSPoint screenPoint = [m_InView.window convertBaseToScreen:windowPoint];
    if(screenPoint.y < mysize.height + vis_frame.origin.y)
        screenPoint.y = mysize.height + vis_frame.origin.y;
    NSPoint loc = [m_InView.window convertScreenToBase:screenPoint];
    loc = [m_InView convertPoint:loc fromView:nil];
    
    [self popUpMenuPositioningItem:0 atLocation:loc inView:m_InView];
}




@end


@implementation MainWindowFilePanelState (ContextMenu)

- (void) RequestContextMenuOn:(const std::vector<const VFSListingItem*>&) _items
                         path:(const char*) _path
                          vfs:(std::shared_ptr<VFSHost>) _host
                       caller:(PanelController*) _caller
{
    PanelController *current_cont = _caller;
    PanelController *opp_cont;
    if(current_cont == m_LeftPanelController)
        opp_cont = m_RightPanelController;
    else if(current_cont == m_RightPanelController)
        opp_cont = m_LeftPanelController;
    else
        assert(0);
    
    NSPoint mouseLoc;
    mouseLoc = [NSEvent mouseLocation]; //get current mouse position
    mouseLoc = [self.window convertScreenToBase:mouseLoc];
    mouseLoc = [self convertPoint:mouseLoc fromView:nil];
    MainWindowFilePanelContextMenu *menu = [MainWindowFilePanelContextMenu alloc];
    menu = [menu initWithData:_items
                       OnPath:_path
                          vfs:_host
                          pos:mouseLoc
                       inView:self
                      mainWnd:self
                       myCont:current_cont
                      oppCont:opp_cont];

    [menu PopUp];
}

@end
