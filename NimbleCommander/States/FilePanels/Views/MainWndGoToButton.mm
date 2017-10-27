// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/CommonPaths.h>
#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include "MainWndGoToButton.h"
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/States/FilePanels/MainWindowFilePanelState.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/States/FilePanels/PanelController.h>
#include <NimbleCommander/States/FilePanels/Favorites.h>
#include <NimbleCommander/Bootstrap/Config.h>

static const auto g_ConfigShowNetworkConnections = "filePanel.general.showNetworkConnectionsInGoToMenu";
static const auto g_ConfigMaxNetworkConnections = "filePanel.general.maximumNetworkConnectionsInGoToMenu";
static const auto g_ConfigShowOthersKey = "filePanel.general.appendOtherWindowsPathsToGoToMenu";

struct AdditionalPath
{
    string path;
    VFSHostWeakPtr vfs;
    
    string VerbosePath() const
    {
        if( auto v = vfs.lock() )
            return PanelDataPersisency::MakeVerbosePathString(*v, path);
        return path;
    }
};

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

@implementation MainWndGoToButtonSelection
@end
@implementation MainWndGoToButtonSelectionVFSPath
@end
@implementation MainWndGoToButtonSelectionSavedNetworkConnection
{
    optional<NetworkConnectionsManager::Connection> m_Connection;
}

- (NetworkConnectionsManager::Connection) connection
{
    return *m_Connection;
}

- (void) setConnection:(NetworkConnectionsManager::Connection)connection
{
    m_Connection = connection;
}
@end

@implementation MainWndGoToButtonSelectionFavorite
{
    FavoriteLocationsStorage::Favorite m_Favorite;
}

- (id) initWithFavorite:(const FavoriteLocationsStorage::Favorite&)_favorite
{
    if( self = [super init] ) {
        m_Favorite = _favorite;
    }
    return self;
}

- (const FavoriteLocationsStorage::Favorite &)favorite
{
    return m_Favorite;
}

@end

@implementation MainWndGoToButton
{
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
        self.menu.delegate = self;
        [self synchronizeTitleAndSelectedItem];
    }
    
    return self;
}

-(void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (vector<AdditionalPath>) otherPanelPaths
{
    vector<AdditionalPath> result;
    
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
            result.emplace_back(ap);
        }
    }
    return result;
}

- (MainWndGoToButtonSelection *)selection
{
    auto *sel = self.selectedItem;
    if(!sel)
        return nil;
    return objc_cast<MainWndGoToButtonSelection>( sel.representedObject );
}

+ (NSImage*) imageForLocation:(const PanelDataPersisency::Location &)_location
{
    if( _location.is_native() ) {
        auto url = [[NSURL alloc] initFileURLWithFileSystemRepresentation:_location.path.c_str()
                                                              isDirectory:true
                                                            relativeToURL:nil];
        if( url ) {
            NSImage *img;
            [url getResourceValue:&img forKey:NSURLEffectiveIconKey error:nil];
            if( img != nil )
                return img;
        }
    }
    else if( _location.is_network() ) {
        return [NSImage imageNamed:NSImageNameNetwork];
    }
    return [NSImage imageNamed:NSImageNameFolder];
}

static vector<shared_ptr<NativeFileSystemInfo>> VolumesToShow()
{
    vector<shared_ptr<NativeFileSystemInfo>> volumes;
    for( auto &i: NativeFSManager::Instance().Volumes() )
        if( i->mount_flags.dont_browse == false )
            volumes.emplace_back(i);
    return volumes;
}

- (void)willPopUp:(NSNotification *) notification
{
    [self removeAllItems];
    NSMenu *menu = self.menu;
    [menu addItem:TitleItem()];
    [self synchronizeTitleAndSelectedItem];
    
    static const auto icon_size = NSMakeSize(NSFont.systemFontSize+3, NSFont.systemFontSize+3);
    
    // Finder Favorites
    const auto favorites = AppDelegate.me.favoriteLocationsStorage.Favorites();
    
    int userdir_ind = 0;
    for( auto &favorite: favorites ) {
        NSMenuItem *menuitem = [NSMenuItem new];
        if( auto title = [NSString stringWithUTF8StdString:favorite.title] )
            menuitem.title = title;
        menuitem.representedObject =
            [[MainWndGoToButtonSelectionFavorite alloc] initWithFavorite:favorite];
        menuitem.keyEquivalent = KeyEquivalentForUserDir(userdir_ind++);
        menuitem.keyEquivalentModifierMask = 0;
        menuitem.image = [MainWndGoToButton imageForLocation:favorite.location->hosts_stack];
        menuitem.image.size = icon_size;
        [menu addItem:menuitem];
    }

    [menu addItem:NSMenuItem.separatorItem];
    
    // VOLUMES
    for(auto &i: VolumesToShow()) {
        NSMenuItem *menuitem = [NSMenuItem new];
        menuitem.title = i->verbose.name;
        menuitem.representedObject = SelectionForNativeVFSPath(i->mounted_at_path);
        menuitem.image = [i->verbose.icon copy];
        menuitem.image.size = icon_size;
        [menu addItem:menuitem];
    }
    
    // Recent Network Connections
    if( GlobalConfig().GetBool(g_ConfigShowNetworkConnections) ) {
        static auto network_image = []{
            NSImage *m = [NSImage imageNamed:NSImageNameNetwork];
            m.size = icon_size;
            return m;
        }();
        
        auto connections = NetworkConnectionsManager::Instance().AllConnectionsByMRU();

        auto limit = max( GlobalConfig().GetInt(g_ConfigMaxNetworkConnections), 0);
        while(connections.size() > limit)
            connections.pop_back();
        
        if(!connections.empty()) {
            [menu addItem:NSMenuItem.separatorItem];
        
            for(auto &c:connections) {
                NSMenuItem *menuitem = [NSMenuItem new];
                menuitem.title = [NSString stringWithUTF8StdString: NetworkConnectionsManager::Instance().TitleForConnection(c)];
                menuitem.image = network_image;
                
                MainWndGoToButtonSelectionSavedNetworkConnection *info = [MainWndGoToButtonSelectionSavedNetworkConnection new];
                info.connection = c;
                menuitem.representedObject = info;
                
                [menu addItem:menuitem];
            }
        }
    }
    
    if( GlobalConfig().GetBool(g_ConfigShowOthersKey) ) {
        auto paths = self.otherPanelPaths;
        if( !paths.empty() ) {
            [menu addItem:NSMenuItem.separatorItem];
            for( const auto &i: paths ) {
                NSMenuItem *menuitem = [NSMenuItem new];
                
                static const auto attributes = @{NSFontAttributeName:[NSFont menuFontOfSize:0]};
                menuitem.title = StringByTruncatingToWidth([NSString stringWithUTF8StdString:i.VerbosePath()],
                                                           600,
                                                           kTruncateAtMiddle,
                                                           attributes);
                MainWndGoToButtonSelectionVFSPath *p = [[MainWndGoToButtonSelectionVFSPath alloc] init];
                p.path = i.path;
                p.vfs = i.vfs;
                menuitem.representedObject = p;
                [menu addItem:menuitem];
            }
        }
    }
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
