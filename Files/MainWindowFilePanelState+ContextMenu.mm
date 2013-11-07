//
//  MainWindowFilePanelState+ContextMenu.m
//  Files
//
//  Created by Michael G. Kazakov on 07.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState+ContextMenu.h"
#import "Common.h"
#import "PanelAux.h"
#import "LSUrls.h"

struct OpenWithHandler
{
    std::string path;
    NSString *app_name;
    NSImage  *app_icon;
    NSString *app_version;
    
    bool is_default;
    
    inline bool operator<(const OpenWithHandler& _r) const
    {
        return [app_name localizedCompare:_r.app_name] < 0;
    }
};

static bool ExposeOpenWithHandler(const std::string &_path, OpenWithHandler &_hndl)
{
//    static const double icon_size = [NSFont systemFontSize];
    static const double icon_size = 14;
    
    NSString *path = [NSString stringWithUTF8String:_path.c_str()];
    NSBundle *handler_bundle = [NSBundle bundleWithPath:path];
    if(handler_bundle == nil)
        return false;
    
    NSString* version = [[handler_bundle infoDictionary] objectForKey:@"CFBundleVersion"];
    
    NSString *appName = [[NSFileManager defaultManager] displayNameAtPath: path];
    NSImage *appicon = [[NSWorkspace sharedWorkspace] iconForFile:path];
    [appicon setSize:NSMakeSize(icon_size, icon_size)];
    
    _hndl.is_default = false;
    _hndl.path = _path;
    _hndl.app_name = appName;
    _hndl.app_icon = appicon;
    _hndl.app_version = version;
    
    return true;
}


@interface MainWindowFilePanelContextMenu : NSMenu


- (id) initWithData:(const std::vector<const VFSListingItem*>&) _items
             OnPath:(const char*)_path
                vfs:(std::shared_ptr<VFSHost>) _host
                pos:(NSPoint)_pos
             inView:(NSView*)_in_view;

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
    
    int                         m_DirsCount;
    int                         m_FilesCount;
}

- (id) initWithData:(const std::vector<const VFSListingItem*>&) _items
             OnPath:(const char*)_path
                vfs:(std::shared_ptr<VFSHost>) _host
                pos:(NSPoint)_pos
             inView:(NSView*)_in_view
{
    self = [super init];
    if(self)
    {
        assert(IsPathWithTrailingSlash(_path));
        m_Host = _host;
        m_DirPath = _path;
        m_Pos = _pos;
        m_InView = _in_view;
        m_DirsCount = m_FilesCount = 0;
        
        for(auto &i: _items)
        {
            m_Items.push_back(i->Name());
            
            if(i->IsDir()) m_DirsCount++;
            if(i->IsReg()) m_FilesCount++;
        }
    
        [self Stuffing:_items];
    
        
    }
    return self;
}

- (void) Stuffing:(const std::vector<const VFSListingItem*>&) _items
{
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
        }
        
        LauchServicesHandlers items_handlers;
        LauchServicesHandlers::DoMerge(&per_item_handlers, &items_handlers);
        
        NSMenu *submenu = [NSMenu new];
        
        // prepare open with handlers information
        for(int i = 0; i < items_handlers.paths.size(); ++i)
        { // TODO: exclude duplicates here
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
                [submenu addItem:item];

                [submenu addItem:[NSMenuItem separatorItem]];
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
                [submenu addItem:item];
                any_handlers_added = true;
            }

        // separate them
        if(!any_handlers_added)
            [submenu addItem:[[NSMenuItem alloc] initWithTitle:@"<None>" action:nil keyEquivalent:@""]];
        [submenu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *item = [NSMenuItem new];
        [item setTitle:@"Other..."];
        [item setTarget:self];
        [item setAction:@selector(OnOpenWithOther:)];
        [submenu addItem:item];
        
        NSMenuItem *submenu_item = [NSMenuItem new];
        [submenu_item setTitle:@"Open With"];
        [submenu_item setSubmenu:submenu];
        [self addItem:submenu_item];
    }
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

- (void) OpenItemsWithApp:(const char*)_app_path
{
    for(auto &i: m_Items) {
        char full_path[MAXPATHLEN];
        sprintf(full_path, "%s%s", m_DirPath.c_str(), i.c_str());
        PanelVFSFileWorkspaceOpener::Open(full_path, m_Host, _app_path);
    }
}

- (void)OnOpenWithOther:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setDirectoryURL:[[NSURL alloc] initFileURLWithPath:@"/Applications" isDirectory:true]];
    [panel setAllowedFileTypes:[NSArray arrayWithObject:@"app"]];
    [panel beginSheetModalForWindow:[m_InView window]
                  completionHandler:^(NSInteger result){
                      if(result == NSFileHandlingPanelOKButton)
                          [self OpenItemsWithApp:[[panel URL]fileSystemRepresentation]];
                  }];
}

- (void) PopUp
{
    [self popUpMenuPositioningItem:0 atLocation:m_Pos inView:m_InView];
}

@end


@implementation MainWindowFilePanelState (ContextMenu)

- (void) RequestContextMenuOn:(const std::vector<const VFSListingItem*>&) _items
                         path:(const char*) _path
                          vfs:(std::shared_ptr<VFSHost>) _host
                       caller:(PanelController*) _caller
{

    NSPoint mouseLoc;
    mouseLoc = [NSEvent mouseLocation]; //get current mouse position
    mouseLoc = [self.window convertScreenToBase:mouseLoc];
    mouseLoc = [self convertPoint:mouseLoc fromView:nil];
    MainWindowFilePanelContextMenu *menu = [[MainWindowFilePanelContextMenu alloc] initWithData:_items
                                                                                         OnPath:_path
                                                                                            vfs:_host
                                                                                            pos:mouseLoc
                                                                                         inView:self];
    [menu PopUp];
}

@end
