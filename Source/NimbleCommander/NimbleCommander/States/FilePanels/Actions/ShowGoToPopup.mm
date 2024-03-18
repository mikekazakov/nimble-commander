// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ShowGoToPopup.h"
#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include <VFS/VFSListingInput.h>
#include <CUI/FilterPopUpMenu.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/NativeVFSHostInstance.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>
#include <NimbleCommander/Core/VFSInstanceManager.h>
#include <NimbleCommander/States/MainWindowController.h>
#include "../Favorites.h"
#include "../MainWindowFilePanelState.h"
#include "../PanelController.h"
#include "../MainWindowFilePanelsStateToolbarDelegate.h"
#include "NavigateHistory.h"
#include "OpenNetworkConnection.h"
#include "../PanelHistory.h"
#include <Panel/PanelData.h>
#include <Panel/TagsStorage.h>
#include "../PanelView.h"
#include "../Helpers/LocationFormatter.h"
#include "Helpers.h"
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <Utility/PathManip.h>
#include <Utility/Tags.h>
#include <Base/dispatch_cpp.h>
#include <fmt/printf.h>
#include <pstld/pstld.h>

using namespace nc::panel;

static const auto g_ConfigShowNetworkConnections = "filePanel.general.showNetworkConnectionsInGoToMenu";
static const auto g_ConfigMaxNetworkConnections = "filePanel.general.maximumNetworkConnectionsInGoToMenu";
static const auto g_ConfigShowOthersKey = "filePanel.general.appendOtherWindowsPathsToGoToMenu";
static const auto g_IconSize = NSMakeSize(16, 16);
static const auto g_TextFont = [NSFont menuFontOfSize:13];
static const auto g_TextAttributes = @{NSFontAttributeName: [NSFont menuFontOfSize:13]};
static const auto g_MaxTextWidth = 600;

@interface GoToPopupListActionMediator : NSObject
- (instancetype)initWithState:(MainWindowFilePanelState *)_state
                     andPanel:(PanelController *)_panel
                   networkMgr:(NetworkConnectionsManager &)_net_mgr;
- (void)callout:(id)sender;
@end

@implementation GoToPopupListActionMediator {
    MainWindowFilePanelState *m_State;
    PanelController *m_Panel;
    NetworkConnectionsManager *m_NetMgr;
}

- (instancetype)initWithState:(MainWindowFilePanelState *)_state
                     andPanel:(PanelController *)_panel
                   networkMgr:(NetworkConnectionsManager &)_net_mgr
{
    self = [super init];
    if( self ) {
        m_State = _state;
        m_Panel = _panel;
        m_NetMgr = &_net_mgr;
    }
    return self;
}

- (void)callout:(id)sender
{
    if( auto menu_item = nc::objc_cast<NSMenuItem>(sender) ) {
        auto any_holder = nc::objc_cast<AnyHolder>(menu_item.representedObject);
        if( !any_holder )
            return;

        if( m_State ) {
            [m_State revealPanel:m_Panel];
            if( !m_Panel.isActive && m_State.goToForcesPanelActivation )
                [m_State ActivatePanelByController:m_Panel];
        }

        [self performGoTo:any_holder.any sender:sender];
    }
}

- (void)performGoTo:(const std::any &)_context sender:(id)sender
{
    if( auto favorite_ptr = std::any_cast<std::shared_ptr<const FavoriteLocationsStorage::Location>>(&_context) )
        [self handlePersistentLocation:(*favorite_ptr)->hosts_stack];
    else if( auto favorite = std::any_cast<FavoriteLocationsStorage::Location>(&_context) )
        [self handlePersistentLocation:favorite->hosts_stack];
    else if( auto plain_path = std::any_cast<std::string>(&_context) ) {
        auto request = std::make_shared<DirectoryChangeRequest>();
        request->RequestedDirectory = *plain_path;
        request->VFS = nc::bootstrap::NativeVFSHostInstance().SharedPtr();
        request->PerformAsynchronous = true;
        request->InitiatedByUser = true;
        [m_Panel GoToDirWithContext:request];
    }
    else if( auto connection = std::any_cast<NetworkConnectionsManager::Connection>(&_context) )
        nc::panel::actions::OpenExistingNetworkConnection(*m_NetMgr).Perform(m_Panel, sender);
    else if( auto vfs_path = std::any_cast<nc::vfs::VFSPath>(&_context) ) {
        auto request = std::make_shared<DirectoryChangeRequest>();
        request->RequestedDirectory = vfs_path->Path();
        request->VFS = vfs_path->Host();
        request->PerformAsynchronous = true;
        request->InitiatedByUser = true;
        [m_Panel GoToDirWithContext:request];
    }
    else if( auto promise = std::any_cast<std::pair<nc::core::VFSInstancePromise, std::string>>(&_context) )
        [self handleVFSPromiseInstance:promise->first path:promise->second];
    else if( auto listing_promise = std::any_cast<nc::panel::ListingPromise>(&_context) )
        nc::panel::ListingPromiseLoader{}.Load(*listing_promise, m_Panel);
    else if( auto tag = std::any_cast<nc::utility::Tags::Tag>(&_context) )
        [self handleTag:*tag];
    else
        fmt::print(
            stderr, "GoToPopupListActionMediator performGoTo: unknown context type '{}'.\n", _context.type().name());
}

- (void)handlePersistentLocation:(const PersistentLocation &)_location
{
    using nc::panel::actions::AsyncPersistentLocationRestorer;
    auto restorer = AsyncPersistentLocationRestorer(m_Panel, m_Panel.vfsInstanceManager);
    auto handler = [path = _location.path, panel = m_Panel](VFSHostPtr _host) {
        dispatch_to_main_queue([=] {
            auto request = std::make_shared<DirectoryChangeRequest>();
            request->RequestedDirectory = path;
            request->VFS = _host;
            request->PerformAsynchronous = true;
            request->InitiatedByUser = true;
            [panel GoToDirWithContext:request];
        });
    };
    restorer.Restore(_location, std::move(handler), nullptr);
}

- (void)handleVFSPromiseInstance:(const nc::core::VFSInstancePromise &)_promise path:(const std::string &)_path
{
    using nc::panel::actions::AsyncVFSPromiseRestorer;
    auto restorer = AsyncVFSPromiseRestorer(m_Panel, m_Panel.vfsInstanceManager);
    auto handler = [path = _path, panel = m_Panel](VFSHostPtr _host) {
        dispatch_to_main_queue([=] {
            auto request = std::make_shared<DirectoryChangeRequest>();
            request->RequestedDirectory = path;
            request->VFS = _host;
            request->PerformAsynchronous = true;
            request->InitiatedByUser = true;
            [panel GoToDirWithContext:request];
        });
    };
    restorer.Restore(_promise, std::move(handler), nullptr);
}

- (void)handleTag:(const nc::utility::Tags::Tag &)_tag
{
    // The Spotlight query is done in a background in the panel's loading queue
    auto task = [tag = _tag, fetch_flags = m_Panel.vfsFetchingFlags, panel = m_Panel](
                    const std::function<bool()> &_is_cancelled) {
        auto items = nc::utility::Tags::GatherAllItemsWithTag(tag.Label());
        std::vector<VFSListingPtr> listings(items.size());
        auto vfs = nc::bootstrap::NativeVFSHostInstance().SharedPtr(); // TODO: DI instead

        // Load listing per each query result in parallel
        pstld::transform(items.begin(),    //
                         items.end(),      //
                         listings.begin(), //
                         [&](const std::filesystem::path &_path) -> VFSListingPtr {
                             if( _is_cancelled && _is_cancelled() )
                                 return nullptr;
                             VFSListingPtr listing;
                             vfs->FetchSingleItemListing(_path.c_str(), listing, fetch_flags, _is_cancelled);
                             return listing;
                         });
        if( _is_cancelled && _is_cancelled() )
            return;

        // There might be failures to fetch a listing - remove these null listings explicitly
        std::erase_if(listings, [](auto &_l) { return _l == nullptr; });

        // Combine the listings into a single non-uniform one and load it in the main thread
        auto listing_input = VFSListing::Compose(listings);
        listing_input.title = tag.Label();
        if( auto combined_listing = VFSListing::Build(std::move(listing_input)) )
            dispatch_to_main_queue([=] { [panel loadListing:combined_listing]; });
    };
    [m_Panel commitCancelableLoadingTask:std::move(task)];
}

@end

namespace nc::panel::actions {

static NSString *ShrinkMenuItemTitle(NSString *_title);

static std::vector<std::shared_ptr<const utility::NativeFileSystemInfo>>
VolumesToShow(utility::NativeFSManager &_native_fs_manager)
{
    std::vector<std::shared_ptr<const utility::NativeFileSystemInfo>> volumes;
    for( auto &i : _native_fs_manager.Volumes() )
        if( i->mount_flags.dont_browse == false )
            volumes.emplace_back(i);
    return volumes;
}

static std::vector<NetworkConnectionsManager::Connection>
LimitedRecentConnections(const NetworkConnectionsManager &_manager)
{
    auto connections = _manager.AllConnectionsByMRU();

    auto limit = std::max(GlobalConfig().GetInt(g_ConfigMaxNetworkConnections), 0);
    if( static_cast<int>(connections.size()) > limit )
        connections.resize(limit);

    return connections;
}

static std::vector<vfs::VFSPath> OtherWindowsPaths(MainWindowFilePanelState *_current)
{
    std::vector<vfs::VFSPath> current_paths;
    for( auto &p : _current.filePanelsCurrentPaths )
        current_paths.emplace_back(std::get<1>(p), std::get<0>(p));

    std::vector<vfs::VFSPath> other_paths;
    for( auto ctr : NCAppDelegate.me.mainWindowControllers )
        if( auto state = ctr.filePanelsState; state != _current )
            for( auto &p : state.filePanelsCurrentPaths )
                other_paths.emplace_back(std::get<1>(p), std::get<0>(p));

    other_paths.erase(
        remove_if(begin(other_paths),
                  end(other_paths),
                  [&](auto &_p) { return find(begin(current_paths), end(current_paths), _p) != end(current_paths); }),
        end(other_paths));

    sort(begin(other_paths), end(other_paths));

    other_paths.erase(unique(begin(other_paths), end(other_paths)), end(other_paths));

    return other_paths;
}

static std::vector<std::pair<core::VFSInstancePromise, std::string>>
ProduceLocationsForParentDirectories(const VFSListing &_listing, core::VFSInstanceManager &_vfs_mgr)
{
    if( !_listing.IsUniform() ) {
        auto msg = "ProduceLocationsForParentDirectories: _listing should be uniform";
        throw std::invalid_argument(msg);
    }

    std::vector<std::pair<core::VFSInstancePromise, std::string>> result;

    auto host = _listing.Host();
    std::filesystem::path dir = EnsureNoTrailingSlash(_listing.Directory());
    while( host ) {

        bool brk = false;
        do {
            if( dir == "/" )
                brk = true;

            result.emplace_back(_vfs_mgr.TameVFS(host), dir == "/" ? dir.native() : dir.native() + "/");

            dir = dir.parent_path();
        } while( !brk );

        dir = host->JunctionPath();
        dir = dir.parent_path();

        host = host->Parent();
    }

    if( !result.empty() )
        result.erase(begin(result));

    return result;
}

namespace {

class MenuItemBuilder
{
public:
    MenuItemBuilder(const NetworkConnectionsManager &_conn_manager, id _action_target);
    NSMenuItem *MenuItemForFavorite(const FavoriteLocationsStorage::Favorite &_f);
    NSMenuItem *MenuItemForLocation(const FavoriteLocationsStorage::Location &_f);
    NSMenuItem *MenuItemForVolume(const utility::NativeFileSystemInfo &_i);
    NSMenuItem *MenuItemForConnection(const NetworkConnectionsManager::Connection &_c);
    NSMenuItem *MenuItemForPath(const vfs::VFSPath &_p);
    NSMenuItem *MenuItemForPromiseAndPath(const core::VFSInstanceManager::Promise &_promise, const std::string &_path);
    NSMenuItem *MenuItemForListingPromise(const ListingPromise &_promise);
    NSMenuItem *MenuItemForFinderTags(const utility::Tags::Tag &_tag);

private:
    const NetworkConnectionsManager &m_ConnectionManager;
    id m_ActionTarget;
    loc_fmt::Formatter::RenderOptions m_FmtOpts = static_cast<loc_fmt::Formatter::RenderOptions>(
        loc_fmt::Formatter::RenderMenuTitle | loc_fmt::Formatter::RenderMenuTooltip |
        loc_fmt::Formatter::RenderMenuIcon);
};

} // namespace

static NSString *KeyEquivalent(int _ind)
{
    switch( _ind ) {
        case 0:
            return @"1";
        case 1:
            return @"2";
        case 2:
            return @"3";
        case 3:
            return @"4";
        case 4:
            return @"5";
        case 5:
            return @"6";
        case 6:
            return @"7";
        case 7:
            return @"8";
        case 8:
            return @"9";
        case 9:
            return @"0";
        case 10:
            return @"-";
        case 11:
            return @"=";
        default:
            return @"";
    }
}

static void SetupHotkeys(NSMenu *_menu)
{
    auto items = _menu.itemArray;
    int hotkey_index = 0;
    for( int ind = 1, e = static_cast<int>(items.count); ind != e; ++ind )
        if( auto i = objc_cast<NSMenuItem>([items objectAtIndex:ind]) ) {
            if( i.separatorItem )
                break;
            i.keyEquivalent = KeyEquivalent(hotkey_index++);
            i.keyEquivalentModifierMask = 0;
        }
}

GoToPopupsBase::GoToPopupsBase(NetworkConnectionsManager &_net_mgr,
                               nc::utility::NativeFSManager &_native_fs_mgr,
                               const nc::panel::TagsStorage &_tags_storage)
    : m_NetMgr{_net_mgr}, m_NativeFSMgr{_native_fs_mgr}, m_Tags{_tags_storage}
{
}

std::tuple<NSMenu *, GoToPopupListActionMediator *>
GoToPopupsBase::BuidInitialMenu(MainWindowFilePanelState *_state, PanelController *_panel, NSString *_title) const
{
    FilterPopUpMenu *menu = [[FilterPopUpMenu alloc] initWithTitle:_title];
    menu.font = g_TextFont;

    auto mediator = [[GoToPopupListActionMediator alloc] initWithState:_state andPanel:_panel networkMgr:m_NetMgr];
    [menu itemAtIndex:0].representedObject = mediator; // a hacky way to prolong longevity

    return {menu, mediator};
}

NSMenu *GoToPopupsBase::BuildGoToMenu(MainWindowFilePanelState *_state, PanelController *_panel) const
{
    const auto [menu, action_target] =
        BuidInitialMenu(_state, _panel, NSLocalizedString(@"Go to", "Goto popup menu title"));

    MenuItemBuilder builder{m_NetMgr, action_target};

    for( auto &f : NCAppDelegate.me.favoriteLocationsStorage->Favorites() )
        [menu addItem:builder.MenuItemForFavorite(f)];

    [menu addItem:NSMenuItem.separatorItem];

    for( auto &i : VolumesToShow(m_NativeFSMgr) )
        [menu addItem:builder.MenuItemForVolume(*i)];

    if( GlobalConfig().GetBool(g_ConfigShowNetworkConnections) )
        if( auto connections = LimitedRecentConnections(m_NetMgr); !connections.empty() ) {
            [menu addItem:NSMenuItem.separatorItem];
            for( auto &c : connections )
                [menu addItem:builder.MenuItemForConnection(c)];
        }

    if( GlobalConfig().GetBool(g_ConfigShowOthersKey) )
        if( auto paths = OtherWindowsPaths(_state); !paths.empty() ) {
            [menu addItem:NSMenuItem.separatorItem];
            for( auto &p : paths )
                [menu addItem:builder.MenuItemForPath(p)];
        }

    SetupHotkeys(menu);

    return menu;
}

NSMenu *GoToPopupsBase::BuildConnectionsQuickList(PanelController *_panel) const
{
    const auto [menu, action_target] =
        BuidInitialMenu(nil, _panel, NSLocalizedString(@"Connections", "Connections popup menu title in file panels"));

    MenuItemBuilder builder{m_NetMgr, action_target};

    for( auto &c : m_NetMgr.AllConnectionsByMRU() )
        [menu addItem:builder.MenuItemForConnection(c)];

    SetupHotkeys(menu);

    return menu;
}

NSMenu *GoToPopupsBase::BuildFavoritesQuickList(PanelController *_panel) const
{
    const auto [menu, action_target] =
        BuidInitialMenu(nil, _panel, NSLocalizedString(@"Favorites", "Favorites popup menu subtitle in file panels"));

    MenuItemBuilder builder{m_NetMgr, action_target};

    for( auto &f : NCAppDelegate.me.favoriteLocationsStorage->Favorites() )
        [menu addItem:builder.MenuItemForFavorite(f)];

    auto frequent = NCAppDelegate.me.favoriteLocationsStorage->FrecentlyUsed(10);
    if( !frequent.empty() ) {
        [menu addItem:NSMenuItem.separatorItem];

        auto frequent_header = [[NSMenuItem alloc] init];
        frequent_header.title =
            NSLocalizedString(@"Frequently Visited", "Frequently Visited popup menu subtitle in file panels");
        [menu addItem:frequent_header];

        for( auto &f : frequent )
            [menu addItem:builder.MenuItemForLocation(*f)];
    }

    SetupHotkeys(menu);

    return menu;
}

NSMenu *GoToPopupsBase::BuildVolumesQuickList(PanelController *_panel) const
{
    const auto [menu, action_target] =
        BuidInitialMenu(nil, _panel, NSLocalizedString(@"Volumes", "Volumes popup menu title in file panels"));

    MenuItemBuilder builder{m_NetMgr, action_target};

    for( auto &i : VolumesToShow(m_NativeFSMgr) )
        [menu addItem:builder.MenuItemForVolume(*i)];

    SetupHotkeys(menu);

    return menu;
}

NSMenu *GoToPopupsBase::BuildTagsQuickList(PanelController *_panel) const
{
    const auto [menu, action_target] =
        BuidInitialMenu(nil, _panel, NSLocalizedString(@"Tags", "Tags popup menu title in file panels"));

    MenuItemBuilder builder{m_NetMgr, action_target};
    const auto tags = m_Tags.Get();
    for( auto &tag : tags )
        [menu addItem:builder.MenuItemForFinderTags(tag)];

    SetupHotkeys(menu);

    return menu;
}

NSMenu *GoToPopupsBase::BuildParentFoldersQuickList(PanelController *_panel) const
{
    const auto [menu, action_target] = BuidInitialMenu(
        nil, _panel, NSLocalizedString(@"Parent Folders", "Upper-dirs popup menu title in file panels"));

    MenuItemBuilder builder{m_NetMgr, action_target};

    for( auto &i : ProduceLocationsForParentDirectories(_panel.data.Listing(), _panel.vfsInstanceManager) )
        [menu addItem:builder.MenuItemForPromiseAndPath(i.first, i.second)];

    SetupHotkeys(menu);

    return menu;
}

NSMenu *GoToPopupsBase::BuildHistoryQuickList(PanelController *_panel) const
{
    const auto [menu, action_target] =
        BuidInitialMenu(nil, _panel, NSLocalizedString(@"History", "History popup menu title in file panels"));

    auto history = _panel.history.All();
    if( !history.empty() && _panel.history.IsRecording() )
        history.pop_back();
    reverse(begin(history), end(history));

    MenuItemBuilder builder{m_NetMgr, action_target};

    for( auto &i : history )
        [menu addItem:builder.MenuItemForListingPromise(i.get())];

    SetupHotkeys(menu);

    return menu;
}

static bool RerouteGoToEventToLeftToolbarButton(MainWindowFilePanelState *_target, id _sender)
{
    if( objc_cast<NSButton>(_sender) )
        return false;

    const auto toolbar = _target.windowStateToolbar;
    const auto delegate = objc_cast<MainWindowFilePanelsStateToolbarDelegate>(toolbar.delegate);
    if( !delegate )
        return false;

    if( !delegate.leftPanelGoToButton || !delegate.leftPanelGoToButton.window )
        return false;

    dispatch_to_main_queue([b = delegate.leftPanelGoToButton, t = _target] { [b performClick:t]; });
    return true;
}

void ShowLeftGoToPopup::Perform(MainWindowFilePanelState *_target, id _sender) const
{
    if( RerouteGoToEventToLeftToolbarButton(_target, _sender) )
        return;

    const auto menu = BuildGoToMenu(_target, _target.leftPanelController);

    if( auto button = objc_cast<NSButton>(_sender) )
        [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, button.bounds.size.height + 4) inView:button];

    else
        [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(4, _target.bounds.size.height - 8) inView:_target];
}

static bool RerouteGoToEventToRightToolbarButton(MainWindowFilePanelState *_target, id _sender)
{
    if( objc_cast<NSButton>(_sender) )
        return false;

    const auto toolbar = _target.windowStateToolbar;
    const auto delegate = objc_cast<MainWindowFilePanelsStateToolbarDelegate>(toolbar.delegate);
    if( !delegate )
        return false;

    if( !delegate.rightPanelGoToButton || !delegate.rightPanelGoToButton.window )
        return false;

    dispatch_to_main_queue([b = delegate.rightPanelGoToButton, t = _target] { [b performClick:t]; });
    return true;
}

void ShowRightGoToPopup::Perform(MainWindowFilePanelState *_target, id _sender) const
{
    if( RerouteGoToEventToRightToolbarButton(_target, _sender) )
        return;

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

static void PopupQuickList(NSMenu *_menu, PanelController *_target)
{
    NSPoint p;
    p.x = (_target.view.bounds.size.width - _menu.size.width) / 2.;
    p.y = _target.view.bounds.size.height - _target.view.headerBarHeight - 4;

    [_menu popUpMenuPositioningItem:nil atLocation:p inView:_target.view];
}

void ShowConnectionsQuickList::Perform(PanelController *_target, id) const
{
    const auto menu = BuildConnectionsQuickList(_target);
    PopupQuickList(menu, _target);
}

void ShowFavoritesQuickList::Perform(PanelController *_target, id) const
{
    const auto menu = BuildFavoritesQuickList(_target);
    PopupQuickList(menu, _target);
}

void ShowVolumesQuickList::Perform(PanelController *_target, id) const
{
    const auto menu = BuildVolumesQuickList(_target);
    PopupQuickList(menu, _target);
}

bool ShowParentFoldersQuickList::Predicate(PanelController *_target) const
{
    return _target.isUniform;
}

void ShowParentFoldersQuickList::Perform(PanelController *_target, id) const
{
    const auto menu = BuildParentFoldersQuickList(_target);
    PopupQuickList(menu, _target);
}

void ShowHistoryQuickList::Perform(PanelController *_target, id) const
{
    const auto menu = BuildHistoryQuickList(_target);
    PopupQuickList(menu, _target);
}

ShowTagsQuickList::ShowTagsQuickList(NetworkConnectionsManager &_net_mgr,
                                     nc::utility::NativeFSManager &_native_fs_mgr,
                                     const nc::panel::TagsStorage &_tags_storage,
                                     const nc::config::Config &_config)
    : GoToPopupsBase(_net_mgr, _native_fs_mgr, _tags_storage), m_Config(_config)
{
}

bool ShowTagsQuickList::Predicate(PanelController *) const
{
    return m_Config.GetBool("filePanel.FinderTags.enable");
}

void ShowTagsQuickList::Perform(PanelController *_target, id) const
{
    const auto menu = BuildTagsQuickList(_target);
    PopupQuickList(menu, _target);
}

MenuItemBuilder::MenuItemBuilder(const NetworkConnectionsManager &_conn_manager, id _action_target)
    : m_ConnectionManager(_conn_manager), m_ActionTarget(_action_target)
{
}

NSMenuItem *MenuItemBuilder::MenuItemForFavorite(const FavoriteLocationsStorage::Favorite &_f)
{
    auto menu_item = [[NSMenuItem alloc] init];
    menu_item.target = m_ActionTarget;
    menu_item.action = @selector(callout:);
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:std::any{_f.location}];
    auto rep = loc_fmt::FavoriteFormatter{m_ConnectionManager}.Render(m_FmtOpts, _f);
    menu_item.title = ShrinkMenuItemTitle(rep.menu_title);
    menu_item.toolTip = rep.menu_tooltip;
    menu_item.image = rep.menu_icon;
    return menu_item;
}

NSMenuItem *MenuItemBuilder::MenuItemForLocation(const FavoriteLocationsStorage::Location &_f)
{
    auto menu_item = [[NSMenuItem alloc] init];
    menu_item.target = m_ActionTarget;
    menu_item.action = @selector(callout:);
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:std::any{_f}];
    auto rep = loc_fmt::FavoriteLocationFormatter{m_ConnectionManager}.Render(m_FmtOpts, _f);
    menu_item.title = ShrinkMenuItemTitle(rep.menu_title);
    menu_item.toolTip = rep.menu_tooltip;
    menu_item.image = rep.menu_icon;
    return menu_item;
}

NSMenuItem *MenuItemBuilder::MenuItemForVolume(const utility::NativeFileSystemInfo &_volume)
{
    auto menu_item = [[NSMenuItem alloc] init];
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:std::any{_volume.mounted_at_path}];
    menu_item.target = m_ActionTarget;
    menu_item.action = @selector(callout:);
    auto rep = loc_fmt::VolumeFormatter{}.Render(m_FmtOpts, _volume);
    menu_item.title = ShrinkMenuItemTitle(rep.menu_title);
    menu_item.toolTip = rep.menu_tooltip;
    menu_item.image = rep.menu_icon;
    return menu_item;
}

NSMenuItem *MenuItemBuilder::MenuItemForConnection(const NetworkConnectionsManager::Connection &_c)
{
    auto menu_item = [[NSMenuItem alloc] init];
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:std::any{_c}];
    menu_item.target = m_ActionTarget;
    menu_item.action = @selector(callout:);
    auto rep = loc_fmt::NetworkConnectionFormatter{}.Render(m_FmtOpts, _c);
    menu_item.title = ShrinkMenuItemTitle(rep.menu_title);
    menu_item.toolTip = rep.menu_tooltip;
    menu_item.image = rep.menu_icon;
    return menu_item;
}

NSMenuItem *MenuItemBuilder::MenuItemForPath(const vfs::VFSPath &_p)
{
    auto menu_item = [[NSMenuItem alloc] init];
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:std::any{_p}];
    menu_item.target = m_ActionTarget;
    menu_item.action = @selector(callout:);
    auto rep = loc_fmt::VFSPathFormatter{}.Render(m_FmtOpts, *_p.Host(), _p.Path());
    menu_item.title = ShrinkMenuItemTitle(rep.menu_title);
    menu_item.toolTip = rep.menu_tooltip;
    menu_item.image = rep.menu_icon;
    return menu_item;
}

NSMenuItem *MenuItemBuilder::MenuItemForPromiseAndPath(const core::VFSInstanceManager::Promise &_promise,
                                                       const std::string &_path)
{
    auto menu_item = [[NSMenuItem alloc] init];
    auto data = std::pair<core::VFSInstanceManager::Promise, std::string>{_promise, _path};
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:std::any{std::move(data)}];
    menu_item.target = m_ActionTarget;
    menu_item.action = @selector(callout:);
    auto rep = loc_fmt::VFSPromiseFormatter{}.Render(m_FmtOpts, _promise, _path);
    menu_item.title = ShrinkMenuItemTitle(rep.menu_title);
    menu_item.toolTip = rep.menu_tooltip;
    menu_item.image = rep.menu_icon;
    return menu_item;
}

NSMenuItem *MenuItemBuilder::MenuItemForListingPromise(const ListingPromise &_promise)
{
    const auto menu_item = [[NSMenuItem alloc] init];
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:std::any{_promise}];
    menu_item.target = m_ActionTarget;
    menu_item.action = @selector(callout:);
    auto rep = loc_fmt::ListingPromiseFormatter{}.Render(m_FmtOpts, _promise);
    menu_item.title = ShrinkMenuItemTitle(rep.menu_title);
    menu_item.toolTip = rep.menu_tooltip;
    menu_item.image = rep.menu_icon;
    return menu_item;
}

NSMenuItem *MenuItemBuilder::MenuItemForFinderTags(const utility::Tags::Tag &_tag)
{
    const auto menu_item = [[NSMenuItem alloc] init];
    menu_item.representedObject = [[AnyHolder alloc] initWithAny:std::any{_tag}];
    menu_item.target = m_ActionTarget;
    menu_item.action = @selector(callout:);
    auto rep = loc_fmt::VFSFinderTagsFormatter{}.Render(m_FmtOpts, _tag);
    menu_item.title = ShrinkMenuItemTitle(rep.menu_title);
    menu_item.toolTip = rep.menu_tooltip;
    menu_item.image = rep.menu_icon;
    return menu_item;
}

static NSString *ShrinkMenuItemTitle(NSString *_title)
{
    return StringByTruncatingToWidth(_title, g_MaxTextWidth, kTruncateAtMiddle, g_TextAttributes);
}

} // namespace nc::panel::actions
