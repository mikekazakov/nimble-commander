//
//  MainWndGoToButton.m
//  Directories
//
//  Created by Michael G. Kazakov on 11.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWndGoToButton.h"
#import "AppDelegate.h"
#import "Common.h"
#import "MainWindowFilePanelState.h"
#import "MainWindowController.h"
#import "common_paths.h"
#import "NativeFSManager.h"
#import "PanelController.h"

// TODO: make this less stupid
struct AdditionalPath
{
    string path;
    VFSHostWeakPtr vfs;
    
    string VerbosePath() const
    {
        VFSHostPtr host = vfs.lock();
        if(!host)
            return path;
        
        array<VFSHost*, 32> hosts;
        int hosts_n = 0;
            
        VFSHost *cur = host.get();
        while(cur) {
            hosts[hosts_n++] = cur;
            cur = cur->Parent().get();
        }
        
        string s;
        while(hosts_n > 0)
            s += hosts[--hosts_n]->VerboseJunctionPath();
        s += path;
        return s;
    }
};

static vector<NSURL*> GetFindersFavorites()
{
    // thanks Adam Strzelecki nanoant.com
    // https://gist.github.com/nanoant/1244807
    
    vector<NSURL*> result;
    
    UInt32 seed;
    LSSharedFileListRef sflRef = LSSharedFileListCreate(NULL, kLSSharedFileListFavoriteItems, NULL);
    NSArray *list = (NSArray *)CFBridgingRelease(LSSharedFileListCopySnapshot(sflRef, &seed));
    
	for(NSObject *object in list) {
		LSSharedFileListItemRef sflItemRef = (__bridge LSSharedFileListItemRef)object;
		CFURLRef urlRef = NULL;
		LSSharedFileListItemResolve(sflItemRef,
                                    kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes,
                                    &urlRef,
                                    NULL);
        
        if(urlRef != 0) {
            NSURL* url = (__bridge NSURL*)urlRef;
            
            if([url.scheme isEqualToString:@"file"] &&
               [url.resourceSpecifier rangeOfString:@".cannedSearch/"].location == NSNotFound)
                result.emplace_back(url);
            CFRelease(urlRef);
        }
	}
    
	CFRelease(sflRef);
    
    return result;
}

static vector<NSURL*> GetHardcodedFavorites()
{
    auto url = [](CommonPaths::Path _p) {
        return [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:CommonPaths::Get(_p)]
                          isDirectory:true];
    };
    vector<NSURL*> result;
    result.emplace_back(url(CommonPaths::Home));
    result.emplace_back(url(CommonPaths::Desktop));
    result.emplace_back(url(CommonPaths::Documents));
    result.emplace_back(url(CommonPaths::Downloads));
    result.emplace_back(url(CommonPaths::Movies));
    result.emplace_back(url(CommonPaths::Music));
    result.emplace_back(url(CommonPaths::Pictures));
    return result;
}

static NSString *KeyEquivalentForUserDir(int _dir_ind)
{
    switch(_dir_ind) {
        case  0: return @"1";
        case  1: return @"2";
        case  2: return @"3";
        case  3: return @"4";
        case  4: return @"5";
        case  5: return @"6";
        case  6: return @"7";
        case  7: return @"8";
        case  8: return @"9";
        case  9: return @"0";
        case 10: return @"-";
        case 11: return @"=";
        default: return @"";
    }
}

static NSMenuItem *TitleItem()
{
    static NSImage *m = [NSImage imageNamed:NSImageNamePathTemplate];
    
    NSMenuItem *menuitem = [NSMenuItem new];
    menuitem.title = @"";
    menuitem.image = m;
    return menuitem;
}

static MainWndGoToButtonSelectionVFSPath *SelectionForNativeVFSPath(const string &_path)
{
    MainWndGoToButtonSelectionVFSPath *p = [[MainWndGoToButtonSelectionVFSPath alloc] init];
    p.path = _path;
    p.vfs = VFSNativeHost::SharedHost();
    return p;
}

static MainWndGoToButtonSelectionVFSPath *SelectionForNativeVFSPath(NSURL *_url)
{
    if(!_url || !_url.path)
        return nil;
    return SelectionForNativeVFSPath(_url.path.fileSystemRepresentationSafe);
}

@implementation MainWndGoToButtonSelection
@end
@implementation MainWndGoToButtonSelectionVFSPath
@end
@implementation MainWndGoToButtonSelectionSavedNetworkConnection
@end

@implementation MainWndGoToButton
{
    vector<NSURL*> m_FinderFavorites;
    vector<shared_ptr<NativeFileSystemInfo>> m_Volumes;
    vector<AdditionalPath> m_OtherPanelsPaths;
    
    string              m_CurrentPath;
    weak_ptr<VFSHost>   m_CurrentVFS;
    
    NSPoint   m_AnchorPoint;
    bool      m_IsRight;

    __weak MainWindowFilePanelState *m_Owner;
}

@synthesize owner = m_Owner;
@synthesize isRight = m_IsRight;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(willPopUp:)
                                                   name:@"NSPopUpButtonWillPopUpNotification"
                                                 object:self];
        
        self.bezelStyle = NSTexturedRoundedBezelStyle;
        self.pullsDown = true;
        self.refusesFirstResponder = true;
        [self.menu addItem:TitleItem()];
        [self synchronizeTitleAndSelectedItem];
    }
    
    return self;
}

-(void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void) UpdateUrls
{
    m_Volumes.clear();
    for(auto &i: NativeFSManager::Instance().Volumes())
        if(i->mount_flags.dont_browse == false)
            m_Volumes.emplace_back(i);
    
    m_FinderFavorites = GetFindersFavorites();
    if(m_FinderFavorites.empty()) // something bad happened, fallback to hardcoded version
        m_FinderFavorites = GetHardcodedFavorites(); // (not sure if this will be ever called)
}

- (void) UpdateOtherPanelPaths
{
    m_OtherPanelsPaths.clear();
    
    bool append = [[NSUserDefaults standardUserDefaults] boolForKey:@"FilePanelsGeneralAppendOtherWindowsPathsToGoToMenu"];
    if(!append) return;
    
    MainWindowFilePanelState *owner = m_Owner;
    vector<tuple<string,VFSHostPtr>> current_panels_paths = owner.filePanelsCurrentPaths;
    
    vector<tuple<string,VFSHostPtr>> other_panels_paths;
    
    for(auto ctr: AppDelegate.me.mainWindowControllers) {
        MainWindowFilePanelState *state = ctr.filePanelsState;
        if(state == owner)
            continue;
        auto paths = state.filePanelsCurrentPaths;
        for(auto &i:paths)
            other_panels_paths.emplace_back(i);
    }

    // paths manipulation
    if(!other_panels_paths.empty()) {
        // sort by VFS and then by path
        sort(begin(other_panels_paths), end(other_panels_paths), [](auto &_1, auto &_2) {
            if(get<1>(_1) != get<1>(_2))
                return get<1>(_1) < get<1>(_2);
            return get<0>(_1) < get<0>(_2);
        });
        
        // erase one which are equal to current panel paths
        other_panels_paths.erase(remove_if(begin(other_panels_paths),
                                           end(other_panels_paths),
                                           [&](auto &_t) {
                                               for(auto &i:current_panels_paths)
                                                   if(get<1>(_t) == get<1>(i) && get<0>(_t) == get<0>(i))
                                                       return true;
                                               return false;
                                           }),
                                 end(other_panels_paths)
                                 );
        
        // exclude duplicates in vector itself
        other_panels_paths.erase( unique(begin(other_panels_paths), end(other_panels_paths)), end(other_panels_paths) );
        
        for(auto &i:other_panels_paths) {
            AdditionalPath ap;
            ap.path = get<0>(i);
            ap.vfs = get<1>(i);
            m_OtherPanelsPaths.emplace_back(ap);
        }
    }
}

- (MainWndGoToButtonSelection *)selection
{
    auto *sel = self.selectedItem;
    if(!sel)
        return nil;
    return objc_cast<MainWndGoToButtonSelection>( sel.representedObject );
}

- (int) countCommonCharsWithPath:(const string&)_str inVFS:(const VFSHostPtr&)_vfs
{
    if(m_CurrentVFS.lock() != _vfs)
        return 0;
    return m_CurrentPath.find(_str) == 0 ? (int)_str.length() : 0;
}

- (void)willPopUp:(NSNotification *) notification
{
    [self updateCurrentPanelPath];
    [self UpdateUrls];
    [self UpdateOtherPanelPaths];
    
    [self removeAllItems];
    NSMenu *menu = self.menu;
    [menu addItem:TitleItem()];
    [self synchronizeTitleAndSelectedItem];
    
    static const auto icon_size = NSMakeSize(NSFont.systemFontSize, NSFont.systemFontSize);
    static auto network_image = []{
        NSImage *m = [NSImage imageNamed:NSImageNameNetwork];
        m.size = icon_size;
        return m;
    }();
    
    size_t common_path_max = 0;
    NSMenuItem *common_item = nil;

    // Finder Favorites
    int userdir_ind = 0;
    for (NSURL *url: m_FinderFavorites) {
        NSString *name;
        [url getResourceValue:&name forKey:NSURLLocalizedNameKey error:nil];
        NSMenuItem *menuitem = [NSMenuItem new];
        menuitem.title = name;
        menuitem.representedObject = SelectionForNativeVFSPath(url);
        [menu addItem:menuitem];

        NSImage *img;
        [url getResourceValue:&img forKey:NSURLEffectiveIconKey error:nil];
        if(img != nil) {
            img.size = icon_size;
            menuitem.image = img;
        }
  
        int common_path = [self countCommonCharsWithPath:url.path.fileSystemRepresentationSafe
                                                   inVFS:VFSNativeHost::SharedHost()];
        if(common_path > common_path_max) {
            common_path_max = common_path;
            common_item = menuitem;
        }

        menuitem.keyEquivalent = KeyEquivalentForUserDir(userdir_ind++);
        menuitem.keyEquivalentModifierMask = 0;
    }

    [menu addItem:NSMenuItem.separatorItem];
    
    // VOLUMES
    for(auto &i: m_Volumes) {
        NSMenuItem *menuitem = [NSMenuItem new];
        menuitem.title = i->verbose.name;
        menuitem.representedObject = SelectionForNativeVFSPath(i->mounted_at_path);
        if(i->verbose.icon != nil) {
            NSImage *img = [i->verbose.icon copy];
            img.size = icon_size;
            menuitem.image = img;
        }
        [menu addItem:menuitem];

        int common_path = [self countCommonCharsWithPath:i->mounted_at_path
                                                   inVFS:VFSNativeHost::SharedHost()];
        if(common_path > common_path_max) {
            common_path_max = common_path;
            common_item = menuitem;
        }
    }
    
    // Recent Network Connections
    if( true /* some checks from defaults*/) {
        auto connections = SavedNetworkConnectionsManager::Instance().Connections();
        int max = 4; // read this from defaults later
        if(connections.size() > max)
            connections.resize(max);
        
        if(!connections.empty()) {
            [menu addItem:NSMenuItem.separatorItem];
        
            for(auto &c:connections) {
                NSMenuItem *menuitem = [NSMenuItem new];
                menuitem.title = [NSString stringWithUTF8StdString:SavedNetworkConnectionsManager::Instance().TitleForConnection(c)];
                menuitem.image = network_image;
                
                MainWndGoToButtonSelectionSavedNetworkConnection *info = [MainWndGoToButtonSelectionSavedNetworkConnection new];
                info.connection = c;
                menuitem.representedObject = info;
                
                [menu addItem:menuitem];
            }
        }
    }
    
    // OTHER PANELS
    if(!m_OtherPanelsPaths.empty()) {
        [menu addItem:NSMenuItem.separatorItem];
        for(const auto &i: m_OtherPanelsPaths) {
            NSMenuItem *menuitem = [NSMenuItem new];

            static NSDictionary* attributes = [NSDictionary dictionaryWithObject:[NSFont menuFontOfSize:0] forKey:NSFontAttributeName];
            menuitem.title = StringByTruncatingToWidth([NSString stringWithUTF8StdString:i.VerbosePath()],
                                                       600,
                                                       kTruncateAtMiddle,
                                                       attributes);
            MainWndGoToButtonSelectionVFSPath *p = [[MainWndGoToButtonSelectionVFSPath alloc] init];
            p.path = i.path;
            p.vfs = i.vfs;
            menuitem.representedObject = p;
            [menu addItem:menuitem];
            
            int common_path = [self countCommonCharsWithPath:i.path
                                                       inVFS:i.vfs.lock()];
            if(common_path > common_path_max) {
                common_path_max = common_path;
                common_item = menuitem;
            }
        }
    }
    
    if(common_item != nil)
        common_item.state = NSOnState;
    
    menu.delegate = self;
}

- (void)updateCurrentPanelPath
{
    m_CurrentPath.clear();
    m_CurrentVFS.reset();
    
    auto *state = (MainWindowFilePanelState *) m_Owner;
    if(!state)
        return;
    
    auto *panel = m_IsRight ? state.rightPanelController : state.leftPanelController;
    if(!panel)
        return;
    
    m_CurrentPath = panel.currentDirectoryPath;
    m_CurrentVFS = panel.vfs;
}

- (void)menuDidClose:(NSMenu *)menu
{
    for(NSMenuItem* i in self.menu.itemArray)
        i.keyEquivalent = @"";
}

- (NSRect)confinementRectForMenu:(NSMenu *)menu onScreen:(NSScreen *)screen
{
    if(self.window != nil)
        return NSZeroRect;
    
    // if we're here - then this button is not contained in a window - toolbar is hidden
    
    NSSize sz = self.menu.size;
    
    if([(MainWindowFilePanelState*)m_Owner window].styleMask & NSFullScreenWindowMask)
        sz.height += 4; // some extra room to ensure that there will be no scrolling
    
    NSRect rc = NSMakeRect(m_AnchorPoint.x, m_AnchorPoint.y - sz.height, sz.width, sz.height);
    if(m_IsRight)
        rc.origin.x -= sz.width;
    
    return rc;
}

- (void) popUp
{
    auto *state = (MainWindowFilePanelState *) m_Owner;
    if(!state) {
        m_AnchorPoint = NSMakePoint(0, 0);
        return;
    }
    
    if(m_IsRight) {
        NSPoint p = NSMakePoint(state.frame.size.width, state.frame.size.height);
        p = [state convertPoint:p toView:nil];
        p = [state.window convertRectToScreen:NSMakeRect(p.x, p.y, 1, 1)].origin;
        m_AnchorPoint = p;
    }
    else {
        NSPoint p = NSMakePoint(0, state.frame.size.height);
        p = [state convertPoint:p toView:nil];
        p = [state.window convertRectToScreen:NSMakeRect(p.x, p.y, 1, 1)].origin;
        m_AnchorPoint = p;
    }
    
    [self performClick:self];
}

@end
