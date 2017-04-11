#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include <NimbleCommander/GeneralUI/FilterPopUpMenu.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>
#include <NimbleCommander/States/MainWindowController.h>
#include "../Favorites.h"
#include "../MainWindowFilePanelState.h"
#include "../PanelController.h"
#include "ShowGoToPopup.h"

static const auto g_ConfigShowNetworkConnections = "filePanel.general.showNetworkConnectionsInGoToMenu";
static const auto g_ConfigMaxNetworkConnections = "filePanel.general.maximumNetworkConnectionsInGoToMenu";
static const auto g_ConfigShowOthersKey = "filePanel.general.appendOtherWindowsPathsToGoToMenu";
static const auto g_IconSize = NSMakeSize(16, 16);
static const auto g_TextFont = [NSFont menuFontOfSize:13];
static const auto g_TextAttributes = @{NSFontAttributeName:[NSFont menuFontOfSize:13]};
static const auto g_MaxTextWidth = 600;

@interface GoToPopupListActionMediator : NSObject
- (instancetype) initWithState:(MainWindowFilePanelState *)_state
                      andPanel:(PanelController*)_panel;
- (void)callout:(id)sender;
@end


@implementation GoToPopupListActionMediator
{
    MainWindowFilePanelState *m_State;
    PanelController *m_Panel;
}

- (instancetype) initWithState:(MainWindowFilePanelState *)_state
                      andPanel:(PanelController*)_panel
{
    self = [super init];
    if( self ) {
        m_State = _state;
        m_Panel = _panel;
    }
    return self;
}

- (void)callout:(id)sender
{
    if( ![sender respondsToSelector:@selector(representedObject)] )
        return;
    auto any_holder = objc_cast<AnyHolder>([sender representedObject]);
    if( !any_holder )
        return;
    
    if( m_State ) {
        [m_State revealPanel:m_Panel];
        if( !m_Panel.isActive && m_State.goToForcesPanelActivation )
            [m_State ActivatePanelByController:m_Panel];
    }
    
    [self performGoTo:any_holder.any];
}

- (void) performGoTo:(const any&)_context
{
    if( auto favorite = any_cast<shared_ptr<const FavoriteLocationsStorage::Location>>(&_context) )
        [m_Panel goToPersistentLocation:(*favorite)->hosts_stack];
    else if( auto plain_path = any_cast<string>(&_context) )
        [m_Panel GoToDir:*plain_path vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
    else if( auto connection = any_cast<NetworkConnectionsManager::Connection>(&_context) )
        [m_Panel GoToSavedConnection:*connection];
    else if( auto vfs_path = any_cast<VFSPath>(&_context) )
        [m_Panel GoToDir:vfs_path->Path() vfs:vfs_path->Host() select_entry:"" async:true];
    else if( auto promise = any_cast<pair<VFSInstanceManager::Promise, string>>(&_context) )
        [m_Panel GoToVFSPromise:promise->first onPath:promise->second];
}

@end

namespace panel::actions {

static vector<shared_ptr<NativeFileSystemInfo>> VolumesToShow()
{
    vector<shared_ptr<NativeFileSystemInfo>> volumes;
    for( auto &i: NativeFSManager::Instance().Volumes() )
        if( i->mount_flags.dont_browse == false )
            volumes.emplace_back(i);
    return volumes;
}

static vector<NetworkConnectionsManager::Connection> LimitedRecentConnections()
{
    auto connections = NetworkConnectionsManager::Instance().AllConnectionsByMRU();
    
    auto limit = max( GlobalConfig().GetInt(g_ConfigMaxNetworkConnections), 0);
    if( connections.size() > limit )
        connections.resize(limit);
    
    return connections;
}

static vector<VFSPath> OtherWindowsPaths( MainWindowFilePanelState *_current )
{
    vector<VFSPath> current_paths;
    for( auto &p: _current.filePanelsCurrentPaths )
        current_paths.emplace_back( get<1>(p), get<0>(p) );
    
    vector<VFSPath> other_paths;
    for( auto ctr: AppDelegate.me.mainWindowControllers )
        if( auto state = ctr.filePanelsState; state != _current)
            for( auto &p: state.filePanelsCurrentPaths )
                other_paths.emplace_back( get<1>(p), get<0>(p) );
    
    other_paths.erase(remove_if(begin(other_paths),
                                end(other_paths),
                                [&](auto &_p) {
                                    return find(begin(current_paths),
                                                end(current_paths),
                                                _p)
                                            != end(current_paths);
                                }),
                      end(other_paths)
                      );
    
    sort( begin(other_paths), end(other_paths) );
    
    other_paths.erase( unique(begin(other_paths), end(other_paths)), end(other_paths) );
    
    return other_paths;
}

static vector<pair<VFSInstanceManager::Promise, string>> ProduceLocationsForParentDirectories(
    const VFSListing &_listing )
{
    if( !_listing.IsUniform() )
        throw invalid_argument("ProduceLocationsForParentDirectories: _listing should be uniform");
    
    vector<pair<VFSInstanceManager::Promise, string>> result;
    
    auto host = _listing.Host();
    path dir = _listing.Directory();
    if(dir.filename() == ".")
        dir.remove_filename();
    while( host ) {
        
        bool brk = false;
        do {
            if( dir == "/" )
                brk = true;
            
            result.emplace_back(VFSInstanceManager::Instance().TameVFS(host),
                                dir == "/" ? dir.native() : dir.native() + "/");
            
            dir = dir.parent_path();
        } while( !brk );
    

        dir = host->JunctionPath();
        dir = dir.parent_path();
        
        host = host->Parent();
    }
    
    if( !result.empty() )
        result.erase( begin(result) );
    
    return result;
}

static NSImage* ImageForLocation(const PanelDataPersisency::Location &_location)
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

static NSImage *ImageForPromiseAndPath(const VFSInstanceManager::Promise &_promise,
                                       const string& _path )
{
    static const auto workspace = NSWorkspace.sharedWorkspace;
    if( _promise.tag() == VFSNativeHost::Tag )
        if(auto image = [workspace iconForFile:[NSString stringWithUTF8StdString:_path]]) {
            image.size = g_IconSize;
            return image;
        }
    
    static auto image = [NSImage imageNamed:NSImageNameFolder];
    image.size = g_IconSize;
    return image;
}

static auto MenuItemForFavorite( const FavoriteLocationsStorage::Favorite &_f, id _target )
{
    auto menu_item = [[NSMenuItem alloc] init];
    
    if( !_f.title.empty() ) {
        if( auto title = [NSString stringWithUTF8StdString:_f.title] )
            menu_item.title = title;
    }
    else if( auto title = [NSString stringWithUTF8StdString:_f.location->verbose_path] )
        menu_item.title = StringByTruncatingToWidth(title,
                                                    g_MaxTextWidth,
                                                    kTruncateAtMiddle,
                                                    g_TextAttributes);
    if( auto tt = [NSString stringWithUTF8StdString:_f.location->verbose_path] )
        menu_item.toolTip = tt;
    menu_item.target = _target;
    menu_item.action = @selector(callout:);
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:any{_f.location}];
    menu_item.image = ImageForLocation(_f.location->hosts_stack);
    menu_item.image.size = g_IconSize;
    
    return menu_item;
}

static auto MenuItemForLocation(shared_ptr<const FavoriteLocationsStorage::Location> _f, id _target)
{
    auto menu_item = [[NSMenuItem alloc] init];
    
    if( auto title = [NSString stringWithUTF8StdString:_f->verbose_path] ) {
        menu_item.title = StringByTruncatingToWidth(title,
                                                    g_MaxTextWidth,
                                                    kTruncateAtMiddle,
                                                    g_TextAttributes);
        menu_item.toolTip = title;
    }
    menu_item.target = _target;
    menu_item.action = @selector(callout:);
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:any{_f}];
    menu_item.image = ImageForLocation(_f->hosts_stack);
    menu_item.image.size = g_IconSize;
    
    return menu_item;
}

static auto MenuItemForVolume( const NativeFileSystemInfo &_i, id _target )
{
    auto menu_item = [[NSMenuItem alloc] init];
    
    menu_item.title = _i.verbose.name;
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:any{_i.mounted_at_path}];
    menu_item.image = [_i.verbose.icon copy];
    menu_item.image.size = g_IconSize;
    menu_item.target = _target;
    menu_item.action = @selector(callout:);

    return menu_item;
}

static auto MenuItemForConnection( const NetworkConnectionsManager::Connection &_c, id _target )
{
    static const auto network_image = []{
        NSImage *m = [NSImage imageNamed:NSImageNameNetwork];
        m.size = g_IconSize;
        return m;
    }();
    auto menu_item = [[NSMenuItem alloc] init];
    
    menu_item.title = [NSString stringWithUTF8StdString:
        NetworkConnectionsManager::Instance().TitleForConnection(_c)];
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:any{_c}];
    menu_item.image = network_image;
    menu_item.target = _target;
    menu_item.action = @selector(callout:);

    return menu_item;
}

static auto MenuItemForPath( const VFSPath &_p, id _target )
{
    auto menu_item = [[NSMenuItem alloc] init];
    
    auto title = PanelDataPersisency::MakeVerbosePathString(*_p.Host(), _p.Path());
    menu_item.title = StringByTruncatingToWidth([NSString stringWithUTF8StdString:title],
                                                g_MaxTextWidth,
                                                kTruncateAtMiddle,
                                                g_TextAttributes);
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:any{_p}];
    menu_item.target = _target;
    menu_item.action = @selector(callout:);

    return menu_item;
}

static auto MenuItemForPromiseAndPath(const VFSInstanceManager::Promise &_promise,
                                      const string &_path,
                                      id _target )
{
    auto menu_item = [[NSMenuItem alloc] init];
    
    menu_item.title = [NSString stringWithUTF8StdString:_promise.verbose_title() + _path];
    menu_item.image = ImageForPromiseAndPath(_promise, _path);
    auto data = pair<VFSInstanceManager::Promise, string>{_promise, _path};
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:any{move(data)}];
    menu_item.target = _target;
    menu_item.action = @selector(callout:);

    return menu_item;
}

static NSString *KeyEquivalent(int _ind)
{
    switch(_ind) {
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

static void SetupHotkeys( NSMenu *_menu )
{
    auto items = _menu.itemArray;
    int hotkey_index = 0;
    for( int ind = 1; ind < items.count; ++ind )
        if( auto i = objc_cast<NSMenuItem>([items objectAtIndex:ind]) ) {
            if( i.separatorItem )
                break;
            i.keyEquivalent = KeyEquivalent( hotkey_index++ );
            i.keyEquivalentModifierMask = 0;
        }
}

static tuple<NSMenu*, GoToPopupListActionMediator*> BuidInitialMenu(
    MainWindowFilePanelState *_state,
    PanelController *_panel,
    NSString *_title)
{
    FilterPopUpMenu *menu = [[FilterPopUpMenu alloc] initWithTitle:_title];
    menu.font = g_TextFont;
    
    auto mediator = [[GoToPopupListActionMediator alloc] initWithState:_state
                                                              andPanel:_panel];
    [menu itemAtIndex:0].representedObject = mediator; // a hacky way to prolong longevity
    
    return {menu, mediator};
}

static NSMenu *BuildGoToMenu( MainWindowFilePanelState *_state, PanelController *_panel  )
{
    const auto [menu, action_target] = BuidInitialMenu(_state, _panel,
        NSLocalizedString(@"Go to", "Goto popup menu title"));
    
    for( auto &f: AppDelegate.me.favoriteLocationsStorage.Favorites() )
        [menu addItem:MenuItemForFavorite(f, action_target)];

    [menu addItem:NSMenuItem.separatorItem];
    
    for( auto &i: VolumesToShow() )
        [menu addItem:MenuItemForVolume(*i, action_target)];

    if( GlobalConfig().GetBool(g_ConfigShowNetworkConnections) )
        if( auto connections = LimitedRecentConnections(); !connections.empty() ) {
            [menu addItem:NSMenuItem.separatorItem];
            for( auto &c: connections )
                [menu addItem:MenuItemForConnection(c, action_target)];
        }
    
    if( GlobalConfig().GetBool(g_ConfigShowOthersKey) )
        if( auto paths = OtherWindowsPaths(_state); !paths.empty() ) {
            [menu addItem:NSMenuItem.separatorItem];
            for( auto &p: paths )
                [menu addItem:MenuItemForPath(p, action_target)];
        }

    SetupHotkeys(menu);

    return menu;
}

static NSMenu *BuildConnectionsQuickList( PanelController *_panel )
{
    const auto [menu, action_target] = BuidInitialMenu(nil, _panel,
        NSLocalizedString(@"Connections", "Connections popup menu title in file panels"));
    
    for( auto &c: NetworkConnectionsManager::Instance().AllConnectionsByMRU() )
        [menu addItem:MenuItemForConnection(c, action_target)];

    SetupHotkeys(menu);

    return menu;
}

static NSMenu *BuildFavoritesQuickList( PanelController *_panel )
{
    const auto [menu, action_target] = BuidInitialMenu(nil, _panel,
        NSLocalizedString(@"Favorites", "Favorites popup menu subtitle in file panels"));
    
    for( auto &f: AppDelegate.me.favoriteLocationsStorage.Favorites() )
        [menu addItem:MenuItemForFavorite(f, action_target)];

    
    auto frequent = AppDelegate.me.favoriteLocationsStorage.FrecentlyUsed(10);
    if( !frequent.empty() ) {
        [menu addItem:NSMenuItem.separatorItem];

        auto frequent_header = [[NSMenuItem alloc] init];
        frequent_header.title = NSLocalizedString(@"Frequently Visited",
            "Frequently Visited popup menu subtitle in file panels");
        [menu addItem:frequent_header];

        for( auto &f: frequent )
            [menu addItem:MenuItemForLocation(f, action_target)];
    }

    SetupHotkeys(menu);

    return menu;
}

static NSMenu *BuildVolumesQuickList( PanelController *_panel )
{
    const auto [menu, action_target] = BuidInitialMenu(nil, _panel,
        NSLocalizedString(@"Volumes", "Volumes popup menu title in file panels"));
    
    for( auto &i: VolumesToShow() )
        [menu addItem:MenuItemForVolume(*i, action_target)];

    SetupHotkeys(menu);

    return menu;
}

static NSMenu *BuildParentFoldersQuickList( PanelController *_panel )
{
    const auto [menu, action_target] = BuidInitialMenu(nil, _panel,
        NSLocalizedString(@"Parent Folders", "Upper-dirs popup menu title in file panels"));

    for( auto &i: ProduceLocationsForParentDirectories(_panel.data.Listing()) )
        [menu addItem:MenuItemForPromiseAndPath(i.first, i.second, action_target)];

    SetupHotkeys(menu);

    return menu;
}

static NSMenu *BuildHistoryQuickList( PanelController *_panel )
{
    const auto [menu, action_target] = BuidInitialMenu(nil, _panel,
        NSLocalizedString(@"History", "History popup menu title in file panels"));

    auto history = _panel.history.All();
    if( !history.empty() && _panel.history.IsRecording() )
        history.pop_back();
    reverse( begin(history), end(history) );
    
    for( auto &i: history )
        [menu addItem:MenuItemForPromiseAndPath(i.get().vfs, i.get().path, action_target)];

    SetupHotkeys(menu);

    return menu;
}

void ShowLeftGoToPopup::Perform( MainWindowFilePanelState *_target, id _sender )
{
    const auto menu = BuildGoToMenu(_target, _target.leftPanelController);
    
    if( auto button = objc_cast<NSButton>(_sender) )
        [menu popUpMenuPositioningItem:nil
                            atLocation:NSMakePoint(0, button.bounds.size.height + 4)
                                inView:button];

    else
        [menu popUpMenuPositioningItem:nil
                            atLocation:NSMakePoint(4, _target.bounds.size.height - 8)
                                inView:_target];
}

void ShowRightGoToPopup::Perform( MainWindowFilePanelState *_target, id _sender )
{
    const auto menu = BuildGoToMenu(_target, _target.rightPanelController);
    
    if( auto button = objc_cast<NSButton>(_sender) )
        [menu popUpMenuPositioningItem:nil
                            atLocation:NSMakePoint(button.bounds.size.width - menu.size.width,
                                                   button.bounds.size.height + 4)
                                inView:button];
    else
        [menu popUpMenuPositioningItem:nil
                            atLocation:NSMakePoint(_target.bounds.size.width - menu.size.width - 4,
                                                   _target.bounds.size.height - 8)
                                inView:_target];
}

static void PopupQuickList( NSMenu *_menu, PanelController *_target )
{
    NSPoint p;
    p.x = (_target.view.bounds.size.width - _menu.size.width) / 2.;
    p.y = _target.view.bounds.size.height - _target.view.headerBarHeight - 4;
    
    [_menu popUpMenuPositioningItem:nil
                         atLocation:p
                             inView:_target.view];
}

void ShowConnectionsQuickList::Perform( PanelController *_target, id _sender )
{
    PopupQuickList( BuildConnectionsQuickList(_target), _target );
}

void ShowFavoritesQuickList::Perform( PanelController *_target, id _sender )
{
    PopupQuickList( BuildFavoritesQuickList(_target), _target );
}

void ShowVolumesQuickList::Perform( PanelController *_target, id _sender )
{
    PopupQuickList( BuildVolumesQuickList(_target), _target );
}

bool ShowParentFoldersQuickList::Predicate( PanelController *_target )
{
   return _target.isUniform;
}

bool ShowParentFoldersQuickList::ValidateMenuItem( PanelController *_target, NSMenuItem *_item )
{
    return Predicate(_target);
}

void ShowParentFoldersQuickList::Perform( PanelController *_target, id _sender )
{
    PopupQuickList( BuildParentFoldersQuickList(_target), _target );
}

void ShowHistoryQuickList::Perform( PanelController *_target, id _sender )
{
    PopupQuickList( BuildHistoryQuickList(_target), _target );
};

}
