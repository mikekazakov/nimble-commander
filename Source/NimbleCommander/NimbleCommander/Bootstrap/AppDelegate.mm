// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AppDelegate.h"
#include "AppDelegateCPP.h"
#include "AppDelegate+Migration.h"
#include "AppDelegate+MainWindowCreation.h"
#include "AppDelegate+ViewerCreation.h"
#include "Config.h"
#include "ConfigWiring.h"
#include "VFSInit.h"
#include "Interactions.h"
#include "NCHelpMenuDelegate.h"
#include "SparkleShim.h"
#include "PFMoveToApplicationsShim.h"
#include "NativeVFSHostInstance.h"
#include "Actions.h"
#include "NCE.h"

#include <algorithm>
#include <magic_enum.hpp>
#include <spdlog/sinks/stdout_sinks.h>

#include <Base/CommonPaths.h>
#include <Base/CFDefaultsCPP.h>
#include <Base/algo.h>
#include <Base/debug.h>

#include <Utility/NSMenu+ActionsShortcutsManager.h>
#include <Utility/NSMenu+Hierarchical.h>
#include <Utility/NativeFSManagerImpl.h>
#include <Utility/TemporaryFileStorageImpl.h>
#include <Utility/PathManip.h>
#include <Utility/FunctionKeysPass.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>
#include <Utility/UTIImpl.h>
#include <Utility/SystemInformation.h>
#include <Utility/Log.h>
#include <Utility/FSEventsFileUpdateImpl.h>
#include <Utility/SpdLogWindow.h>
#include <Utility/Tags.h>

#include <RoutedIO/RoutedIO.h>
#include <RoutedIO/Log.h>

#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Core/SandboxManager.h>
#include <NimbleCommander/Core/Dock.h>
#include <NimbleCommander/Core/ServicesHandler.h>
#include <NimbleCommander/Core/ConfigBackedNetworkConnectionsManager.h>
#include <NimbleCommander/Core/ConnectionsMenuDelegate.h>
#include <NimbleCommander/Core/Theming/SystemThemeDetector.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/VFSInstanceManagerImpl.h>
#include <NimbleCommander/States/Terminal/ShellState.h>
#include <NimbleCommander/States/MainWindow.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/States/FilePanels/MainWindowFilePanelState.h>
#include <NimbleCommander/States/FilePanels/ExternalEditorInfo.h>
#include <NimbleCommander/States/FilePanels/PanelViewLayoutSupport.h>
#include <NimbleCommander/States/FilePanels/FavoritesImpl.h>
#include <NimbleCommander/States/FilePanels/FavoritesWindowController.h>
#include <NimbleCommander/States/FilePanels/FavoritesMenuDelegate.h>
#include <NimbleCommander/States/FilePanels/Helpers/ClosedPanelsHistoryImpl.h>
#include <NimbleCommander/States/FilePanels/Helpers/RecentlyClosedMenuDelegate.h>
#include <NimbleCommander/Preferences/Preferences.h>

#include <Operations/Pool.h>
#include <Operations/PoolEnqueueFilter.h>
#include <Operations/AggregateProgressTracker.h>

#include <Config/ConfigImpl.h>
#include <Config/ObjCBridge.h>
#include <Config/FileOverwritesStorage.h>
#include <Config/Executor.h>
#include <Config/Log.h>

#include <Viewer/History.h>
#include <Viewer/Log.h>
#include <Viewer/ViewerViewController.h>
#include <Viewer/InternalViewerWindowController.h>
#include <Viewer/Highlighting/FileSettingsStorage.h>

#include <Term/Log.h>

#include <VFS/Log.h>

#include <VFSIcon/Log.h>

#include <Panel/Log.h>
#include <Panel/ExternalTools.h>
#include <Panel/TagsStorage.h>

#include <filesystem>
#include <fstream>
#include <iostream>

using namespace std::literals;
using namespace nc::bootstrap;

static std::optional<std::string> Load(const std::string &_filepath);

static auto g_ConfigDirPostfix = "Config/";
static auto g_StateDirPostfix = "State/";

static nc::config::ConfigImpl *g_Config = nullptr;
static nc::config::ConfigImpl *g_State = nullptr;
static nc::config::ConfigImpl *g_NetworkConnectionsConfig = nullptr;
static nc::utility::TemporaryFileStorageImpl *g_TemporaryFileStorage = nullptr;

static const auto g_ConfigForceFn = "general.alwaysUseFnKeysAsFunctional";
static const auto g_ConfigExternalToolsList = "externalTools.tools_v1";
static const auto g_ConfigLayoutsList = "filePanel.layout.layouts_v1";
static const auto g_ConfigSelectedTheme = "general.theme";
static const auto g_ConfigThemes = "themes";
static const auto g_ConfigExtEditorsList = "externalEditors.editors_v1";
static const auto g_ConfigFinderTags = "filePanel.FinderTags.tags";

nc::config::Config &GlobalConfig() noexcept
{
    assert(g_Config);
    return *g_Config;
}

nc::config::Config &StateConfig() noexcept
{
    assert(g_State);
    return *g_State;
}

static void ResetDefaults()
{
    const auto bundle_id = NSBundle.mainBundle.bundleIdentifier;
    [NSUserDefaults.standardUserDefaults removePersistentDomainForName:bundle_id];
    [NSUserDefaults.standardUserDefaults synchronize];
    g_Config->ResetToDefaults();
    g_State->ResetToDefaults();
    g_Config->Commit();
    g_State->Commit();
}

static void CheckDefaultsReset()
{
    const auto erase_mask =
        NSEventModifierFlagCapsLock | NSEventModifierFlagShift | NSEventModifierFlagOption | NSEventModifierFlagCommand;
    if( (NSEvent.modifierFlags & erase_mask) == erase_mask )
        if( AskUserToResetDefaults() ) {
            ResetDefaults();
            exit(0);
        }
}

template <typename Log>
static void AttachToSink(spdlog::level::level_enum _level, std::shared_ptr<spdlog::sinks::sink> _sink)
{
    Log::Set(std::make_shared<spdlog::logger>(Log::Name(), _sink));
    Log::Get().set_level(_level);
}

static std::span<nc::base::SpdLogger *const> Loggers() noexcept
{
    static const auto loggers = std::to_array({&nc::config::Log::Logger(),
                                               &nc::panel::Log::Logger(),
                                               &nc::routedio::Log::Logger(),
                                               &nc::term::Log::Logger(),
                                               &nc::utility::Log::Logger(),
                                               &nc::vfs::Log::Logger(),
                                               &nc::vfsicon::Log::Logger(),
                                               &nc::viewer::Log::Logger()});
    return loggers;
}

static void SetupLogs()
{
    spdlog::level::level_enum level = spdlog::level::off;
    const auto defaults = NSUserDefaults.standardUserDefaults;
    const auto args = [defaults volatileDomainForName:NSArgumentDomain];
    if( const auto arg_level = nc::objc_cast<NSString>([args objectForKey:@"NCLogLevel"]) ) {
        const auto casted = magic_enum::enum_cast<spdlog::level::level_enum>(arg_level.UTF8String);
        level = casted.value_or(spdlog::level::off);
    }

    if( level < spdlog::level::off ) {
        const auto stdout_sink = std::make_shared<spdlog::sinks::stdout_sink_mt>();
        for( auto logger : Loggers() ) {
            logger->Get().sinks().emplace_back(stdout_sink);
            logger->Get().set_level(level);
        }
    }
}

static NCAppDelegate *g_Me = nil;

@interface NCAppDelegate ()

@property(nonatomic, readonly) nc::core::Dock &dock;

@property(nonatomic) IBOutlet NSMenu *recentlyClosedMenu;

@end

@interface NCViewerWindowDelegateBridge : NSObject <NCViewerWindowDelegate>

- (void)viewerWindowWillShow:(InternalViewerWindowController *)_window;
- (void)viewerWindowWillClose:(InternalViewerWindowController *)_window;

@end

@implementation NCAppDelegate {
    std::vector<NCMainWindowController *> m_MainWindows;
    std::vector<InternalViewerWindowController *> m_ViewerWindows;
    nc::spinlock m_ViewerWindowsLock;
    std::filesystem::path m_SupportDirectory;
    std::filesystem::path m_ConfigDirectory;
    std::filesystem::path m_StateDirectory;
    std::vector<nc::config::Token> m_ConfigObservationTickets;
    upward_flag m_FinishedLaunching;
    std::shared_ptr<nc::panel::FavoriteLocationsStorageImpl> m_Favorites;
    NSMutableArray *m_FilesToOpen;
    NCViewerWindowDelegateBridge *m_ViewerWindowDelegateBridge;
    std::unique_ptr<nc::utility::NativeFSManager> m_NativeFSManager;
    std::shared_ptr<nc::vfs::NativeHost> m_NativeHost;
    std::unique_ptr<nc::utility::FSEventsFileUpdateImpl> m_FSEventsFileUpdate;
    nc::ops::PoolEnqueueFilter m_PoolEnqueueFilter;
    std::unique_ptr<ConfigWiring> m_ConfigWiring;
    std::unique_ptr<nc::SystemThemeDetector> m_SystemThemeDetector;
    std::unique_ptr<nc::ThemesManager> m_ThemesManager;
    NCSpdLogWindowController *m_LogWindowController;
}

@synthesize mainWindowControllers = m_MainWindows;
@synthesize configDirectory = m_ConfigDirectory;
@synthesize stateDirectory = m_StateDirectory;
@synthesize supportDirectory = m_SupportDirectory;
@synthesize recentlyClosedMenu;

- (id)init
{
    self = [super init];
    if( self ) {
        SetupLogs();
        g_Me = self;
        m_FilesToOpen = [[NSMutableArray alloc] init];
        m_ViewerWindowDelegateBridge = [[NCViewerWindowDelegateBridge alloc] init];
        m_FSEventsFileUpdate = std::make_unique<nc::utility::FSEventsFileUpdateImpl>();
        m_NativeFSManager = std::make_unique<nc::utility::NativeFSManagerImpl>();
        m_NativeHost = std::make_shared<nc::vfs::NativeHost>(*m_NativeFSManager, *m_FSEventsFileUpdate);
        CheckDefaultsReset();
        m_SupportDirectory = nc::AppDelegate::SupportDirectory();
        [self setupConfigs];
        m_SystemThemeDetector = std::make_unique<nc::SystemThemeDetector>();
    }
    return self;
}

+ (NCAppDelegate *)me
{
    return g_Me;
}

- (void)applicationWillFinishLaunching:(NSNotification *) [[maybe_unused]] _notification
{
    RegisterAvailableVFS();

    // Init themes manager
    m_ThemesManager = std::make_unique<nc::ThemesManager>(GlobalConfig(), g_ConfigSelectedTheme, g_ConfigThemes);
    // also hook up the appearance change notification with the global application appearance
    auto update_tm_appearance = [self] {
        m_ThemesManager->NotifyAboutSystemAppearanceChange(m_SystemThemeDetector->SystemAppearance());
    };
    auto update_app_appearance = [self] { [NSApp setAppearance:m_ThemesManager->SelectedTheme().Appearance()]; };
    update_tm_appearance();
    update_app_appearance();
    // observe forever
    [[clang::no_destroy]] static auto token =
        m_ThemesManager->ObserveChanges(nc::ThemesManager::Notifications::Appearance, update_app_appearance);
    [[clang::no_destroy]] static auto token1 = m_SystemThemeDetector->ObserveChanges(update_tm_appearance);

    [self themesManager];
    [self favoriteLocationsStorage];
    [self tagsStorage]; // might kickstart a background scanning of the finder tags

    [self updateMainMenuFeaturesByVersionAndState];

    // update menu with current shortcuts layout
    [NSApp.mainMenu nc_setMenuItemShortcutsWithActionsShortcutsManager:self.actionsShortcutsManager];
    [self wireMenuDelegates];

    if( nc::base::AmISandboxed() ) {
        auto &sm = SandboxManager::Instance();
        if( sm.Empty() ) {
            sm.AskAccessForPathSync(nc::base::CommonPaths::Home(), false);
            if( self.mainWindowControllers.empty() ) {
                auto ctrl = [self allocateDefaultMainWindow];
                [ctrl showWindow:self];
            }
        }
    }
}

- (void)wireMenuDelegates
{
    // set up menu delegates. do this via DI to reduce links to AppDelegate in whole codebase
    auto item_for_action = [&](const char *_action) -> NSMenuItem * {
        const std::optional<int> tag = self.actionsShortcutsManager.TagFromAction(_action);
        if( tag == std::nullopt )
            return nil;
        return [NSApp.mainMenu itemWithTagHierarchical:*tag];
    };

    static auto layouts_delegate = [[PanelViewLayoutsMenuDelegate alloc] initWithStorage:*self.panelLayouts];
    item_for_action("menu.view.toggle_layout_1").menu.delegate = layouts_delegate;

    auto manage_fav_item = item_for_action("menu.go.favorites.manage");
    static auto favorites_delegate =
        [[FavoriteLocationsMenuDelegate alloc] initWithStorage:*self.favoriteLocationsStorage
                                             andManageMenuItem:manage_fav_item];
    manage_fav_item.menu.delegate = favorites_delegate;

    auto clear_freq_item = [NSApp.mainMenu itemWithTagHierarchical:14220];
    static auto frequent_delegate =
        [[FrequentlyVisitedLocationsMenuDelegate alloc] initWithStorage:*self.favoriteLocationsStorage
                                                       andClearMenuItem:clear_freq_item];
    clear_freq_item.menu.delegate = frequent_delegate;

    const auto connections_menu_item = item_for_action("menu.go.connect.network_server");
    static const auto conn_delegate = [[ConnectionsMenuDelegate alloc]
        initWithManager:[]() -> nc::panel::NetworkConnectionsManager & { return *g_Me.networkConnectionsManager; }];
    connections_menu_item.menu.delegate = conn_delegate;

    auto panels_locator = []() -> MainWindowFilePanelState * {
        if( auto wnd = nc::objc_cast<NCMainWindow>(NSApp.keyWindow) )
            if( auto ctrl = nc::objc_cast<NCMainWindowController>(wnd.delegate) )
                return ctrl.filePanelsState;
        return nil;
    };
    static const auto recently_closed_delegate =
        [[NCPanelsRecentlyClosedMenuDelegate alloc] initWithMenu:self.recentlyClosedMenu
                                                         storage:self.closedPanelsHistory
                                                   panelsLocator:panels_locator];
    (void)recently_closed_delegate;

    // These menus will have a submenu generated on the fly by according actions.
    // However, it's required for these menu items to always have submenus so that
    // Preferences can detect it and mark its hotkeys as readonly.
    // This solution is horrible but I can find a better one right now.
    item_for_action("menu.file.open_with_submenu").submenu = [NSMenu new];
    item_for_action("menu.file.always_open_with_submenu").submenu = [NSMenu new];

    // Set up a delegate for the Help menu
    static const auto help_delegate = [[NCHelpMenuDelegate alloc] init];
    auto help_menu_item = [NSApp.mainMenu itemWithTagHierarchical:17'000].menu;
    help_menu_item.delegate = help_delegate;
}

- (void)updateMainMenuFeaturesByVersionAndState
{
    // disable some features available in menu by configuration limitation
    auto tag_from_lit = [&](const char *s) { return self.actionsShortcutsManager.TagFromAction(s).value(); };
    auto current_menuitem = [&](const char *s) { return [NSApp.mainMenu itemWithTagHierarchical:tag_from_lit(s)]; };
    auto hide = [&](const char *s) {
        auto item = current_menuitem(s);
        item.alternate = false;
        item.hidden = true;
    };
    // one-way items hiding
    if( nc::base::AmISandboxed() ) {
        hide("menu.view.show_terminal");
        hide("menu.view.panels_position.move_up");
        hide("menu.view.panels_position.move_down");
        hide("menu.view.panels_position.showpanels");
        hide("menu.view.panels_position.focusterminal");
        hide("menu.file.feed_filename_to_terminal");
        hide("menu.file.feed_filenames_to_terminal");
        hide("menu.nimble_commander.toggle_admin_mode");
        hide("menu.go.connect.lanshare");
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *) [[maybe_unused]] _notification
{
    m_FinishedLaunching.toggle();

    if( self.mainWindowControllers.empty() )
        [self applicationOpenUntitledFile:NSApp]; // if there's no restored windows - we'll create a
                                                  // freshly new one

    NSApp.servicesProvider = self;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [NSApp registerServicesMenuSendTypes:@[NSFilenamesPboardType, (__bridge NSString *)kUTTypeFileURL]
                             returnTypes:@[]]; // pasteboard types provided by PanelController
#pragma clang diagnostic pop
    NSUpdateDynamicServices();

    [self temporaryFileStorage]; // implicitly runs the background temp storage purging

    // Non-MAS version extended logic below:
    if( !nc::base::AmISandboxed() ) {
        // setup Sparkle updater stuff
        NSMenuItem *item = [[NSMenuItem alloc] init];
        item.title = NSLocalizedString(@"Check for Updates...",
                                       "Menu item title for check if any Nimble Commander updates are available");
        item.target = NCBootstrapSharedSUUpdaterInstance();
        item.action = NCBootstrapSUUpdaterAction();
        [[NSApp.mainMenu itemAtIndex:0].submenu insertItem:item atIndex:1];

        if( GlobalConfig().GetBool(g_ConfigForceFn) )
            nc::utility::FunctionalKeysPass::Instance().Enable(); // accessibility - remapping functional keys FnXX

        PFMoveToApplicationsFolderIfNecessary();
    }

    m_ConfigWiring = std::make_unique<ConfigWiring>(GlobalConfig(), m_PoolEnqueueFilter);
    m_ConfigWiring->Wire();

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:nil];
}

- (void)setupConfigs
{
    assert(g_Config == nullptr && g_State == nullptr);

    m_ConfigDirectory = m_SupportDirectory / g_ConfigDirPostfix;
    if( !std::filesystem::exists(m_ConfigDirectory) )
        std::filesystem::create_directories(m_ConfigDirectory);

    m_StateDirectory = m_SupportDirectory / g_StateDirPostfix;
    if( !std::filesystem::exists(m_StateDirectory) )
        std::filesystem::create_directories(m_StateDirectory);

    const auto bundle = NSBundle.mainBundle;
    const auto config_defaults_path = [bundle pathForResource:@"Config" ofType:@"json"].fileSystemRepresentationSafe;
    const auto config_defaults = Load(config_defaults_path);
    if( config_defaults == std::nullopt ) {
        std::cerr << "Failed to read the main config file: " << config_defaults_path << '\n';
        exit(-1);
    }

    const auto state_defaults_path = [bundle pathForResource:@"State" ofType:@"json"].fileSystemRepresentationSafe;
    const auto state_defaults = Load(state_defaults_path);
    if( state_defaults == std::nullopt ) {
        std::cerr << "Failed to read the state config file: " << state_defaults_path << '\n';
        exit(-1);
    }

    const auto write_delay = std::chrono::seconds{30};
    const auto reload_delay = std::chrono::seconds{1};

    g_Config = new nc::config::ConfigImpl(
        *config_defaults,
        std::make_shared<nc::config::FileOverwritesStorage>(self.configDirectory / "Config.json"),
        std::make_shared<nc::config::DelayedAsyncExecutor>(write_delay),
        std::make_shared<nc::config::DelayedAsyncExecutor>(reload_delay));

    g_State = new nc::config::ConfigImpl(
        *state_defaults,
        std::make_shared<nc::config::FileOverwritesStorage>(self.stateDirectory / "State.json"),
        std::make_shared<nc::config::DelayedAsyncExecutor>(write_delay),
        std::make_shared<nc::config::DelayedAsyncExecutor>(reload_delay));

    g_NetworkConnectionsConfig = new nc::config::ConfigImpl(
        "",
        std::make_shared<nc::config::FileOverwritesStorage>(self.configDirectory / "NetworkConnections.json"),
        std::make_shared<nc::config::DelayedAsyncExecutor>(write_delay),
        std::make_shared<nc::config::DelayedAsyncExecutor>(reload_delay));

    atexit([] {
        // this callback is quite brutal, but works well. may need to find some more gentle approach
        g_Config->Commit();
        g_State->Commit();
        g_NetworkConnectionsConfig->Commit();
    });
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *) [[maybe_unused]] _app
{
    return NO;
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *) [[maybe_unused]] _state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    NSWindow *window = nil;
    if( [identifier isEqualToString:NCMainWindow.defaultIdentifier] )
        window = [g_Me allocateMainWindowRestoredBySystem].window;
    completionHandler(window, nil);
}

- (IBAction)onMainMenuNewWindow:(id) [[maybe_unused]] _sender
{
    auto ctrl = [self allocateMainWindowRestoredManually];
    [ctrl showWindow:self];
}

- (void)addMainWindow:(NCMainWindowController *)_wnd
{
    m_MainWindows.push_back(_wnd);
}

- (void)removeMainWindow:(NCMainWindowController *)_wnd
{
    auto it = std::ranges::find(m_MainWindows, _wnd);
    if( it != end(m_MainWindows) )
        m_MainWindows.erase(it);
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    if( auto main_wnd = nc::objc_cast<NCMainWindow>(aNotification.object) )
        if( auto main_ctrl = nc::objc_cast<NCMainWindowController>(main_wnd.delegate) ) {
            dispatch_to_main_queue([=] { [self removeMainWindow:main_ctrl]; });
        }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *) [[maybe_unused]] _sender
{
    bool has_running_ops = false;
    auto controllers = self.mainWindowControllers;
    for( const auto &wincont : controllers )
        if( !wincont.operationsPool.Empty() || (wincont.terminalState && wincont.terminalState.isAnythingRunning) ) {
            has_running_ops = true;
            break;
        }

    if( has_running_ops ) {
        if( !AskToExitWithRunningOperations() )
            return NSTerminateCancel;

        for( const auto &wincont : controllers ) {
            wincont.operationsPool.StopAndWaitForShutdown();
            [wincont.terminalState terminate];
        }
    }

    // last cleanup before shutting down here:
    if( m_Favorites )
        m_Favorites->StoreData(StateConfig(), "filePanel.favorites");

    return NSTerminateNow;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *) [[maybe_unused]] _sender
{
    return true;
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)sender
{
    if( !m_FinishedLaunching )
        return false;

    if( !self.mainWindowControllers.empty() )
        return true;

    [self onMainMenuNewWindow:sender];

    return true;
}

- (void)drainFilesToOpen
{
    if( m_FilesToOpen.count == 0 )
        return;
    self.servicesHandler.OpenFiles(m_FilesToOpen);
    [m_FilesToOpen removeAllObjects];
}

- (BOOL)application:(NSApplication *) [[maybe_unused]] _sender openFile:(NSString *)filename
{
    [m_FilesToOpen addObjectsFromArray:@[filename]];
    dispatch_to_main_queue_after(250ms, [] { [g_Me drainFilesToOpen]; });
    return true;
}

- (void)application:(NSApplication *) [[maybe_unused]] _sender openFiles:(NSArray<NSString *> *)filenames
{
    [m_FilesToOpen addObjectsFromArray:filenames];
    dispatch_to_main_queue_after(250ms, [] { [g_Me drainFilesToOpen]; });
    [NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

- (void)openFolderService:(NSPasteboard *)pboard userData:(NSString *)data error:(__strong NSString **)error
{
    self.servicesHandler.OpenFolder(pboard, data, error);
}

- (void)revealItemService:(NSPasteboard *)pboard userData:(NSString *)data error:(__strong NSString **)error
{
    self.servicesHandler.RevealItem(pboard, data, error);
}

- (void)OnPreferencesCommand:(id) [[maybe_unused]] _sender
{
    ShowPreferencesWindow();
}

- (IBAction)OnShowHelp:(id) [[maybe_unused]] _sender
{
    const auto url = [NSBundle.mainBundle URLForResource:@"Help" withExtension:@"pdf"];
    [NSWorkspace.sharedWorkspace openURL:url];
}

- (IBAction)onMainMenuPerformGoToProductForum:(id) [[maybe_unused]] _sender
{
    const auto url = [NSURL URLWithString:@"https://github.com/mikekazakov/nimble-commander/discussions"];
    [NSWorkspace.sharedWorkspace openURL:url];
}

- (IBAction)OnMenuToggleAdminMode:(id) [[maybe_unused]] _sender
{
    using nc::routedio::RoutedIO;
    if( RoutedIO::Instance().Enabled() )
        RoutedIO::Instance().TurnOff();
    else {
        const auto turned_on = RoutedIO::Instance().TurnOn();
        if( !turned_on )
            WarnAboutFailingToAccessPrivilegedHelper();
    }

    self.dock.SetAdminBadge(RoutedIO::Instance().Enabled());
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    static const int admin_mode_tag =
        self.actionsShortcutsManager.TagFromAction("menu.nimble_commander.toggle_admin_mode").value();
    const long tag = item.tag;

    if( tag == admin_mode_tag ) {
        bool enabled = nc::routedio::RoutedIO::Instance().Enabled();
        item.title = enabled ? NSLocalizedString(@"Disable Admin Mode", "Menu item title for disabling an admin mode")
                             : NSLocalizedString(@"Enable Admin Mode", "Menu item title for enabling an admin mode");
        return true;
    }

    return true;
}

- (NCConfigObjCBridge *)config
{
    static auto global_config_bridge = [[NCConfigObjCBridge alloc] initWithConfig:*g_Config];
    return global_config_bridge;
}

- (nc::config::Config &)globalConfig
{
    assert(g_Config);
    return *g_Config;
}

- (nc::config::Config &)stateConfig
{
    assert(g_State);
    return *g_State;
}

- (nc::panel::ExternalToolsStorage &)externalTools
{
    [[clang::no_destroy]] static //
        nc::panel::ExternalToolsStorage storage{g_ConfigExternalToolsList, self.globalConfig};
    return storage;
}

- (const std::shared_ptr<nc::panel::PanelViewLayoutsStorage> &)panelLayouts
{
    [[clang::no_destroy]] static auto i = std::make_shared<nc::panel::PanelViewLayoutsStorage>(g_ConfigLayoutsList);
    return i;
}

- (nc::ThemesManager &)themesManager
{
    assert(m_ThemesManager);
    return *m_ThemesManager;
}

- (ExternalEditorsStorage &)externalEditorsStorage
{
    static auto i = new ExternalEditorsStorage(g_ConfigExtEditorsList);
    return *i;
}

- (const std::shared_ptr<nc::panel::FavoriteLocationsStorage> &)favoriteLocationsStorage
{
    static std::once_flag once;
    std::call_once(once, [&] {
        using t = nc::panel::FavoriteLocationsStorageImpl;
        m_Favorites = std::make_shared<t>(StateConfig(), "filePanel.favorites", self.panelDataPersistency);
    });

    [[clang::no_destroy]] static const std::shared_ptr<nc::panel::FavoriteLocationsStorage> inst = m_Favorites;
    return inst;
}

- (bool)askToResetDefaults
{
    if( AskUserToResetDefaults() ) {
        ResetDefaults();
        return true;
    }
    return false;
}

- (void)addInternalViewerWindow:(InternalViewerWindowController *)_wnd
{
    auto lock = std::lock_guard{m_ViewerWindowsLock};
    m_ViewerWindows.emplace_back(_wnd);
}

- (void)removeInternalViewerWindow:(InternalViewerWindowController *)_wnd
{
    auto lock = std::lock_guard{m_ViewerWindowsLock};
    auto i = std::ranges::find(m_ViewerWindows, _wnd);
    if( i != std::end(m_ViewerWindows) )
        m_ViewerWindows.erase(i);
}

- (InternalViewerWindowController *)findInternalViewerWindowForPath:(const std::string &)_path
                                                              onVFS:(const VFSHostPtr &)_vfs
{
    auto lock = std::lock_guard{m_ViewerWindowsLock};
    auto i = std::ranges::find_if(m_ViewerWindows, [&](auto v) {
        return v.internalViewerController.filePath == _path && v.internalViewerController.fileVFS == _vfs;
    });
    return i != std::end(m_ViewerWindows) ? *i : nil;
    return nil;
}

- (InternalViewerWindowController *)retrieveInternalViewerWindowForPath:(const std::string &)_path
                                                                  onVFS:(const std::shared_ptr<VFSHost> &)_vfs
{
    dispatch_assert_main_queue();
    if( auto window = [self findInternalViewerWindowForPath:_path onVFS:_vfs] )
        return window;
    auto viewer_factory = [](NSRect rc) { return [NCAppDelegate.me makeViewerWithFrame:rc]; };
    auto ctrl = [self makeViewerController];
    auto window = [[InternalViewerWindowController alloc] initWithFilepath:_path
                                                                        at:_vfs
                                                             viewerFactory:viewer_factory
                                                                controller:ctrl];
    window.delegate = m_ViewerWindowDelegateBridge;

    return window;
}

- (IBAction)onMainMenuPerformShowFavorites:(id) [[maybe_unused]] _sender
{
    static __weak FavoritesWindowController *existing_window = nil;
    if( auto w = static_cast<FavoritesWindowController *>(existing_window) ) {
        [w show];
        return;
    }
    auto storage = []() -> nc::panel::FavoriteLocationsStorage & { return *NCAppDelegate.me.favoriteLocationsStorage; };
    FavoritesWindowController *window = [[FavoritesWindowController alloc] initWithFavoritesStorage:storage];
    auto provide_panel = []() -> std::vector<std::pair<VFSHostPtr, std::string>> {
        std::vector<std::pair<VFSHostPtr, std::string>> panel_paths;
        for( const auto &ctr : NCAppDelegate.me.mainWindowControllers ) {
            auto state = ctr.filePanelsState;
            auto paths = state.filePanelsCurrentPaths;
            for( const auto &p : paths )
                panel_paths.emplace_back(std::get<1>(p), std::get<0>(p));
        }
        return panel_paths;
    };
    window.provideCurrentUniformPaths = provide_panel;

    [window show];
    existing_window = window;
}

- (const std::shared_ptr<nc::panel::NetworkConnectionsManager> &)networkConnectionsManager
{
    [[clang::no_destroy]] static const auto mgr =
        std::make_shared<ConfigBackedNetworkConnectionsManager>(*g_NetworkConnectionsConfig, self.nativeFSManager);
    [[clang::no_destroy]] static const std::shared_ptr<nc::panel::NetworkConnectionsManager> int_ptr = mgr;
    return int_ptr;
}

- (nc::ops::AggregateProgressTracker &)operationsProgressTracker
{
    [[clang::no_destroy]] static const auto apt = [] {
        const auto apt = std::make_shared<nc::ops::AggregateProgressTracker>();
        apt->SetProgressCallback([](double _progress) { g_Me.dock.SetProgress(_progress); });
        return apt;
    }();
    return *apt;
}

- (nc::core::Dock &)dock
{
    static const auto instance = new nc::core::Dock;
    return *instance;
}

- (nc::core::VFSInstanceManager &)vfsInstanceManager
{
    static const auto instance = new nc::core::VFSInstanceManagerImpl;
    return *instance;
}

- (const std::shared_ptr<nc::panel::ClosedPanelsHistory> &)closedPanelsHistory
{
    [[clang::no_destroy]] static const auto impl = std::make_shared<nc::panel::ClosedPanelsHistoryImpl>();
    [[clang::no_destroy]] static const std::shared_ptr<nc::panel::ClosedPanelsHistory> history = impl;
    return history;
}

- (NCMainWindowController *)windowForExternalRevealRequest
{
    NCMainWindowController *target_window = nil;
    for( NSWindow *wnd in NSApplication.sharedApplication.orderedWindows )
        if( auto wc = nc::objc_cast<NCMainWindowController>(wnd.windowController) )
            if( [wc.topmostState isKindOfClass:MainWindowFilePanelState.class] ) {
                target_window = wc;
                break;
            }

    if( !target_window )
        target_window = [self allocateDefaultMainWindow];

    if( target_window )
        [target_window.window makeKeyAndOrderFront:self];

    return target_window;
}

- (nc::core::ServicesHandler &)servicesHandler
{
    auto window_locator = [] { return [g_Me windowForExternalRevealRequest]; };
    [[clang::no_destroy]] static nc::core::ServicesHandler handler(window_locator, self.nativeHostPtr);
    return handler;
}

- (nc::utility::NativeFSManager &)nativeFSManager
{
    return *m_NativeFSManager;
}

static void DoTemporaryFileStoragePurge()
{
    assert(g_TemporaryFileStorage != nullptr);
    const auto deadline = time(nullptr) - (60l * 60l * 24l); // 24 hours back
    g_TemporaryFileStorage->Purge(deadline);

    dispatch_after(6h, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), DoTemporaryFileStoragePurge);
}

- (nc::utility::TemporaryFileStorage &)temporaryFileStorage
{
    const auto instance = [] {
        const auto base_dir = nc::base::CommonPaths::AppTemporaryDirectory();
        const auto prefix = nc::utility::GetBundleID() + ".tmp.";
        g_TemporaryFileStorage = new nc::utility::TemporaryFileStorageImpl(base_dir, prefix);
        dispatch_to_background(DoTemporaryFileStoragePurge);
        return g_TemporaryFileStorage;
    }();

    return *instance;
}

- (nc::viewer::History &)internalViewerHistory
{
    static const auto history_state_path = "viewer.history";
    static const auto instance = [] {
        auto inst = new nc::viewer::History(*g_Config, *g_State, history_state_path);
        auto center = NSNotificationCenter.defaultCenter;
        // Save the history upon application shutdown
        [center addObserverForName:NSApplicationWillTerminateNotification
                            object:nil
                             queue:nil
                        usingBlock:^([[maybe_unused]] NSNotification *_Nonnull note) {
                          inst->SaveToStateConfig();
                        }];
        return inst;
    }();
    return *instance;
}

- (nc::utility::UTIDB &)utiDB
{
    [[clang::no_destroy]] static nc::utility::UTIDBImpl uti_db;
    return uti_db;
}

- (nc::vfs::NativeHost &)nativeHost
{
    return *m_NativeHost;
}

- (const std::shared_ptr<nc::vfs::NativeHost> &)nativeHostPtr
{
    return m_NativeHost;
}

- (nc::utility::FSEventsFileUpdate &)fsEventsFileUpdate
{
    return *m_FSEventsFileUpdate;
}

- (nc::ops::PoolEnqueueFilter &)poolEnqueueFilter
{
    return m_PoolEnqueueFilter;
}

- (IBAction)onMainMenuShowLogs:(id)_sender
{
    if( m_LogWindowController == nil )
        m_LogWindowController = [[NCSpdLogWindowController alloc] initWithLogs:Loggers()];
    [m_LogWindowController showWindow:self];
}

- (nc::panel::TagsStorage &)tagsStorage
{
    [[clang::no_destroy]] static nc::panel::TagsStorage storage(GlobalConfig(), g_ConfigFinderTags);
    static std::once_flag once;
    std::call_once(once, [] {
        if( !storage.Initialized() ) {
            dispatch_to_background([] {
                auto tags = nc::utility::Tags::GatherAllItemsTags();
                storage.Set(tags);
            });
        }
    });
    return storage;
}

- (nc::viewer::hl::SettingsStorage &)syntaxHighlightingSettingsStorage
{
    // if the overrides directory doesn't exist - create it. Check it only once per run
    static std::once_flag once;
    std::call_once(once, [self] {
        const std::filesystem::path overrides_dir = self.supportDirectory / "SyntaxHighlighting";
        std::error_code ec = {};
        if( !std::filesystem::exists(overrides_dir, ec) ) {
            std::filesystem::create_directory(overrides_dir, ec);
        }
    });

    [[clang::no_destroy]] static nc::viewer::hl::FileSettingsStorage storage{
        [NSBundle.mainBundle pathForResource:@"SyntaxHighlighting" ofType:@""].fileSystemRepresentation,
        self.supportDirectory / "SyntaxHighlighting"};

    return storage;
}

- (nc::panel::PanelDataPersistency &)panelDataPersistency
{
    [[clang::no_destroy]] static nc::panel::PanelDataPersistency persistency{*self.networkConnectionsManager};
    return persistency;
}

- (nc::utility::ActionsShortcutsManager &)actionsShortcutsManager
{
    [[clang::no_destroy]] static nc::core::ActionsShortcutsManager manager(
        g_ActionsTags, g_DefaultActionShortcuts, GlobalConfig());
    return manager;
}

@end

static std::optional<std::string> Load(const std::string &_filepath)
{
    std::ifstream in(_filepath, std::ios::in | std::ios::binary);
    if( !in )
        return std::nullopt;

    std::string contents;
    in.seekg(0, std::ios::end);
    contents.resize(in.tellg());
    in.seekg(0, std::ios::beg);
    in.read(contents.data(), contents.size());
    in.close();
    return contents;
}

@implementation NCViewerWindowDelegateBridge

- (void)viewerWindowWillShow:(InternalViewerWindowController *)_window
{
    [NCAppDelegate.me addInternalViewerWindow:_window];
}

- (void)viewerWindowWillClose:(InternalViewerWindowController *)_window
{
    [NCAppDelegate.me removeInternalViewerWindow:_window];
}

@end

namespace nc::bootstrap {

nc::vfs::NativeHost &NativeVFSHostInstance() noexcept
{
    assert(g_Me != nil);
    return NCAppDelegate.me.nativeHost;
}

} // namespace nc::bootstrap
