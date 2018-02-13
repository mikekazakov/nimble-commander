// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Sparkle/Sparkle.h>
#include <LetsMove/PFMoveApplication.h>
#include <Habanero/CommonPaths.h>
#include <Habanero/CFDefaultsCPP.h>
#include <Habanero/algo.h>
#include <Utility/NSMenu+Hierarchical.h>
#include <Utility/NativeFSManager.h>
#include <Utility/PathManip.h>
#include <Utility/FunctionKeysPass.h>
#include <RoutedIO/RoutedIO.h>
#include "../../3rd_Party/NSFileManagerDirectoryLocations/NSFileManager+DirectoryLocations.h"
#include <NimbleCommander/Core/TemporaryNativeFileStorage.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Core/SandboxManager.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/FeedbackManager.h>
#include <NimbleCommander/Core/AppStoreHelper.h>
#include <NimbleCommander/Core/Dock.h>
#include <NimbleCommander/Core/ServicesHandler.h>
#include <NimbleCommander/Core/ConfigBackedNetworkConnectionsManager.h>
#include <NimbleCommander/Core/ConnectionsMenuDelegate.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include <NimbleCommander/States/Terminal/ShellState.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/States/FilePanels/MainWindowFilePanelState.h>
#include <NimbleCommander/States/FilePanels/ExternalToolsSupport.h>
#include <NimbleCommander/States/FilePanels/ExternalEditorInfo.h>
#include <NimbleCommander/States/FilePanels/PanelViewLayoutSupport.h>
#include <NimbleCommander/States/FilePanels/FavoritesImpl.h>
#include <NimbleCommander/States/FilePanels/FavoritesWindowController.h>
#include <NimbleCommander/States/FilePanels/FavoritesMenuDelegate.h>
#include <NimbleCommander/Preferences/Preferences.h>
#include <NimbleCommander/Viewer/InternalViewerController.h>
#include <NimbleCommander/Viewer/InternalViewerWindowController.h>
#include <NimbleCommander/GeneralUI/TrialWindowController.h>
#include <NimbleCommander/GeneralUI/VFSListWindowController.h>
#include <Operations/Pool.h>
#include <Operations/AggregateProgressTracker.h>
#include "AppDelegate.h"
#include "Config.h"
#include "AppDelegate+Migration.h"
#include "ActivationManager.h"
#include "ConfigWiring.h"
#include "VFSInit.h"
#include "Interactions.h"
#include <NimbleCommander/States/MainWindow.h>
#include "AppDelegate+MainWindowCreation.h"
#include <NimbleCommander/States/FilePanels/Helpers/ClosedPanelsHistoryImpl.h>
#include <NimbleCommander/States/FilePanels/Helpers/RecentlyClosedMenuDelegate.h>
#include <NimbleCommander/Core/VFSInstanceManagerImpl.h>

using namespace nc::bootstrap;

static SUUpdater *g_Sparkle = nil;

static auto g_ConfigDirPostfix = @"/Config/";
static auto g_StateDirPostfix = @"/State/";

static GenericConfig *g_Config = nullptr;
static GenericConfig *g_State = nullptr;

static const auto g_ConfigForceFn = "general.alwaysUseFnKeysAsFunctional";
static const auto g_ConfigExternalToolsList = "externalTools.tools_v1";
static const auto g_ConfigLayoutsList = "filePanel.layout.layouts_v1";
static const auto g_ConfigSelectedThemes = "general.theme";
static const auto g_ConfigThemesList = "themes.themes_v1";
static const auto g_ConfigExtEditorsList = "externalEditors.editors_v1";

GenericConfig &GlobalConfig() noexcept
{
    assert(g_Config);
    return *g_Config;
}

GenericConfig &StateConfig() noexcept
{
    assert(g_State);
    return *g_State;
}

static void ResetDefaults()
{
    const auto bundle_id = NSBundle.mainBundle.bundleIdentifier;
    [NSUserDefaults.standardUserDefaults removePersistentDomainForName:bundle_id];
    [NSUserDefaults.standardUserDefaults synchronize];
    GlobalConfig().ResetToDefaults();
    StateConfig().ResetToDefaults();
    GlobalConfig().Commit();
    StateConfig().Commit();
}

static void UpdateMenuItemsPlaceholders( int _tag )
{
    static const auto app_name = (NSString*)[NSBundle.mainBundle.infoDictionary
        objectForKey:@"CFBundleName"];

    if( auto menu_item = [NSApp.mainMenu itemWithTagHierarchical:_tag] ) {
        auto title = menu_item.title;
        title = [title stringByReplacingOccurrencesOfString:@"{AppName}" withString:app_name];
        menu_item.title = title;
    }
}

static void UpdateMenuItemsPlaceholders( const char *_action )
{
    UpdateMenuItemsPlaceholders( ActionsShortcutsManager::Instance().TagFromAction(_action) );
}

static void CheckMASReceipt()
{
    if constexpr ( ActivationManager::ForAppStore() ) {
        const auto path = NSBundle.mainBundle.appStoreReceiptURL.path;
        const auto exists = [NSFileManager.defaultManager fileExistsAtPath:path];
        if( !exists ) {
            cerr << "No receipt - exit the app with code 173" << endl;
            exit(173);
        }
    }
}

static void CheckDefaultsReset()
{
    const auto erase_mask = NSAlphaShiftKeyMask | NSShiftKeyMask |
                            NSAlternateKeyMask | NSCommandKeyMask;
    if( (NSEvent.modifierFlags & erase_mask) == erase_mask )
        if( AskUserToResetDefaults() ) {
            ResetDefaults();
            exit(0);
        }
}

static NCAppDelegate *g_Me = nil;

@interface NCAppDelegate()

@property (nonatomic, readonly) nc::core::Dock& dock;

@property (nonatomic) IBOutlet NSMenu *recentlyClosedMenu;

@end

@implementation NCAppDelegate
{
    vector<NCMainWindowController *>            m_MainWindows;
    vector<InternalViewerWindowController*>     m_ViewerWindows;
    spinlock                                    m_ViewerWindowsLock;
    bool                m_IsRunningTests;
    string              m_SupportDirectory;
    string              m_ConfigDirectory;
    string              m_StateDirectory;
    vector<GenericConfig::ObservationTicket> m_ConfigObservationTickets;
    AppStoreHelper *m_AppStoreHelper;
    upward_flag         m_FinishedLaunching;
    shared_ptr<nc::panel::FavoriteLocationsStorageImpl> m_Favorites;
    NSMutableArray      *m_FilesToOpen;
}

@synthesize isRunningTests = m_IsRunningTests;
@synthesize mainWindowControllers = m_MainWindows;
@synthesize configDirectory = m_ConfigDirectory;
@synthesize stateDirectory = m_StateDirectory;
@synthesize supportDirectory = m_SupportDirectory;
@synthesize appStoreHelper = m_AppStoreHelper;

- (id) init
{
    self = [super init];
    if(self) {
        g_Me = self;
        m_IsRunningTests = NSClassFromString(@"XCTestCase") != nullptr;
        m_FilesToOpen = [[NSMutableArray alloc] init];
        CheckMASReceipt();
        CheckDefaultsReset();
        m_SupportDirectory =
            EnsureTrailingSlash(NSFileManager.defaultManager.
                                applicationSupportDirectory.fileSystemRepresentationSafe);
        [self setupConfigs];
    }
    return self;
}

+ (NCAppDelegate*) me
{
    return g_Me;
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    RegisterAvailableVFS();
    
    NativeFSManager::Instance();
    FeedbackManager::Instance();
    [self themesManager];
    [self favoriteLocationsStorage];
    
    [self updateMainMenuFeaturesByVersionAndState];
    
    // update menu with current shortcuts layout
    ActionsShortcutsManager::Instance().SetMenuShortCuts([NSApp mainMenu]);
    
    [self wireMenuDelegates];
 
    bool showed_modal_dialog = false;
    if( ActivationManager::Instance().Sandboxed() ) {
        auto &sm = SandboxManager::Instance();
        if( sm.Empty() ) {
            sm.AskAccessForPathSync(CommonPaths::Home(), false);
            showed_modal_dialog = true;
            if( self.mainWindowControllers.empty() ) {
                auto ctrl = [self allocateDefaultMainWindow];
                [ctrl showWindow:self];
            }
        }
    }
    
    // if no option already set - ask user to provide anonymous usage statistics
    // ask him only on 5th startup or later
    // ask only if there were no modal dialogs before
    if( !m_IsRunningTests &&
        !showed_modal_dialog &&
        !CFDefaultsGetOptionalBool(GoogleAnalytics::g_DefaultsTrackingEnabledKey) &&
        FeedbackManager::Instance().ApplicationRunsCount() >= 5 ) {
        CFDefaultsSetBool( GoogleAnalytics::g_DefaultsTrackingEnabledKey, AskUserToProvideUsageStatistics() );
        GA().UpdateEnabledStatus();
    }
    
    GA().PostEvent( "Appearance", "Set", self.themesManager.SelectedThemeName().c_str() );
}

- (void) wireMenuDelegates
{
    // set up menu delegates. do this via DI to reduce links to AppDelegate in whole codebase
    auto item_for_action = [](const char *_action){
        auto tag = ActionsShortcutsManager::Instance().TagFromAction(_action);
        return [NSApp.mainMenu itemWithTagHierarchical:tag];
    };
    
    static auto layouts_delegate = [[PanelViewLayoutsMenuDelegate alloc]
                                    initWithStorage:*self.panelLayouts];
    item_for_action("menu.view.toggle_layout_1").menu.delegate = layouts_delegate;

    auto manage_fav_item = item_for_action("menu.go.favorites.manage");
    static auto favorites_delegate = [[FavoriteLocationsMenuDelegate alloc]
                                      initWithStorage:*self.favoriteLocationsStorage
                                      andManageMenuItem:manage_fav_item];
    manage_fav_item.menu.delegate = favorites_delegate;
  
    auto clear_freq_item = [NSApp.mainMenu itemWithTagHierarchical:14220];
    static auto frequent_delegate = [[FrequentlyVisitedLocationsMenuDelegate alloc]
        initWithStorage:*self.favoriteLocationsStorage andClearMenuItem:clear_freq_item];
    clear_freq_item.menu.delegate = frequent_delegate;
    
    const auto connections_menu_item = item_for_action("menu.go.connect.network_server");
    static const auto conn_delegate = [[ConnectionsMenuDelegate alloc] initWithManager:
        []()->NetworkConnectionsManager &{
        return *g_Me.networkConnectionsManager;
    }];
    connections_menu_item.menu.delegate = conn_delegate;
    
    auto panels_locator = []() -> MainWindowFilePanelState* {
        if( auto wnd = objc_cast<NCMainWindow>(NSApp.keyWindow) )
            if( auto ctrl = objc_cast<NCMainWindowController>(wnd.delegate) )
                return ctrl.filePanelsState;
        return nil;
    };
    static const auto recently_closed_delegate = [[NCPanelsRecentlyClosedMenuDelegate alloc]
                                                  initWithMenu:self.recentlyClosedMenu
                                                  storage:self.closedPanelsHistory
                                                  panelsLocator:panels_locator];
    (void)recently_closed_delegate;
}

- (void)updateMainMenuFeaturesByVersionAndState
{
    static NSMenu *original_menu_state = [NSApp.mainMenu copy];
    
    // disable some features available in menu by configuration limitation
    auto tag_from_lit       = [ ](const char *s) { return ActionsShortcutsManager::Instance().TagFromAction(s);             };
    auto current_menuitem   = [&](const char *s) { return [NSApp.mainMenu itemWithTagHierarchical:tag_from_lit(s)];         };
    auto initial_menuitem   = [&](const char *s) { return [original_menu_state itemWithTagHierarchical:tag_from_lit(s)];    };
    auto hide               = [&](const char *s) {
        auto item = current_menuitem(s);
        item.alternate = false;
        item.hidden = true;
    };
    auto enable             = [&](const char *_action, bool _enabled) {
        current_menuitem(_action).action = _enabled ? initial_menuitem(_action).action : nil;
    };
    auto &am = ActivationManager::Instance();
    
    // one-way items hiding
    if( !am.HasTerminal() ) {                   hide("menu.view.show_terminal");
                                                hide("menu.view.panels_position.move_up");
                                                hide("menu.view.panels_position.move_down");
                                                hide("menu.view.panels_position.showpanels");
                                                hide("menu.view.panels_position.focusterminal");
                                                hide("menu.file.feed_filename_to_terminal");
                                                hide("menu.file.feed_filenames_to_terminal"); }
    if( am.ForAppStore() ) {                    hide("menu.nimble_commander.active_license_file");
                                                hide("menu.nimble_commander.purchase_license"); }
    if( am.Type() != ActivationManager::Distribution::Free || am.UsedHadPurchasedProFeatures() ) {
                                                hide("menu.nimble_commander.purchase_pro_features");
                                                hide("menu.nimble_commander.restore_purchases"); }
    if( am.Type() != ActivationManager::Distribution::Trial || am.UserHadRegistered() ) {
                                                hide("menu.nimble_commander.active_license_file");
                                                hide("menu.nimble_commander.purchase_license"); }
    if( !am.HasRoutedIO() )                     hide("menu.nimble_commander.toggle_admin_mode");
    
    // reversible items disabling / enabling
    enable( "menu.file.calculate_checksum",     am.HasChecksumCalculation() );
    enable( "menu.file.find_with_spotlight",    am.HasSpotlightSearch() );
    enable( "menu.go.processes_list",           am.HasPSFS() );
    enable( "menu.go.connect.ftp",              am.HasNetworkConnectivity() );
    enable( "menu.go.connect.sftp",             am.HasNetworkConnectivity() );
    enable( "menu.go.connect.webdav",           am.HasNetworkConnectivity() );
    enable( "menu.go.connect.lanshare",         am.HasLANSharesMounting() );
    enable( "menu.go.connect.dropbox",          am.HasNetworkConnectivity() );
    enable( "menu.go.connect.network_server",   am.HasNetworkConnectivity() );
    enable( "menu.command.system_overview",     am.HasBriefSystemOverview() );
    enable( "menu.command.file_attributes",     am.HasUnixAttributesEditing() );
    enable( "menu.command.volume_information",  am.HasDetailedVolumeInformation() );
    enable( "menu.command.batch_rename",        am.HasBatchRename() );
    enable( "menu.command.internal_viewer",     am.HasInternalViewer() );
    enable( "menu.command.compress_here",       am.HasCompressionOperation() );
    enable( "menu.command.compress_to_opposite",am.HasCompressionOperation() );
    enable( "menu.command.link_create_soft",    am.HasLinksManipulation() );
    enable( "menu.command.link_create_hard",    am.HasLinksManipulation() );
    enable( "menu.command.link_edit",           am.HasLinksManipulation());
    enable( "menu.command.open_xattr",          am.HasXAttrFS() );
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    m_FinishedLaunching.toggle();
    
    if( !m_IsRunningTests && self.mainWindowControllers.empty() )
        [self applicationOpenUntitledFile:NSApp]; // if there's no restored windows - we'll create a freshly new one
    
    NSApp.servicesProvider = self;
    [NSApp registerServicesMenuSendTypes:@[NSFilenamesPboardType, (__bridge NSString *)kUTTypeFileURL]
                             returnTypes:@[]]; // pasteboard types provided by PanelController
    NSUpdateDynamicServices();
    
    // Since we have different app names (Nimble Commander and Nimble Commander Pro) and one
    // fixed menu, we have to emplace the right title upon startup in some menu elements.
    UpdateMenuItemsPlaceholders( "menu.nimble_commander.about" );
    UpdateMenuItemsPlaceholders( "menu.nimble_commander.hide" );
    UpdateMenuItemsPlaceholders( "menu.nimble_commander.quit" );
    UpdateMenuItemsPlaceholders( 17000 ); // Menu->Help
    
    // calling modules running in background
    TemporaryNativeFileStorage::Instance(); // starting background purging implicitly
    
    auto &am = ActivationManager::Instance();
    
    // Non-MAS version stuff below:
    if( !ActivationManager::ForAppStore() && !self.isRunningTests ) {
        if( am.ShouldShowTrialNagScreen() ) // check if we should show a nag screen
            dispatch_to_main_queue_after(500ms, []{ [TrialWindowController showTrialWindow]; });

        // setup Sparkle updater stuff
        g_Sparkle = [SUUpdater sharedUpdater];
        NSMenuItem *item = [[NSMenuItem alloc] init];
        item.title = NSLocalizedString(@"Check for Updates...", "Menu item title for check if any Nimble Commander updates are available");
        item.target = g_Sparkle;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector"
        item.action = @selector(checkForUpdates:);
#pragma clang diagnostic pop
        [[NSApp.mainMenu itemAtIndex:0].submenu insertItem:item atIndex:1];
    }
    
    // initialize stuff related with in-app purchases
    if( ActivationManager::Type() == ActivationManager::Distribution::Free ) {
        m_AppStoreHelper = [AppStoreHelper new];
        m_AppStoreHelper.onProductPurchased = [=](const string &_id){
            if( ActivationManager::Instance().ReCheckProFeaturesInAppPurchased() ) {
                [self updateMainMenuFeaturesByVersionAndState];
                GA().PostEvent("Licensing", "Buy", "Pro features IAP purchased");
            }
        };
        dispatch_to_main_queue_after(500ms, [=]{ [m_AppStoreHelper showProFeaturesWindowIfNeededAsNagScreen]; });
    }
    
    // accessibility stuff for NonMAS version
    if( ActivationManager::Type() == ActivationManager::Distribution::Trial &&
        GlobalConfig().GetBool(g_ConfigForceFn) ) {
        FunctionalKeysPass::Instance().Enable();
    }
    
    if( ActivationManager::Type() == ActivationManager::Distribution::Trial &&
        am.UserHadRegistered() == false &&
        am.IsTrialPeriod() == false )
        self.dock.SetUnregisteredBadge( true );

    if( !ActivationManager::ForAppStore() && !self.isRunningTests )
        PFMoveToApplicationsFolderIfNecessary();
    
    ConfigWiring{GlobalConfig()}.Wire();
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:nil];
}

- (void) setupConfigs
{
    assert( g_Config == nullptr && g_State == nullptr );
    auto fm = NSFileManager.defaultManager;

    NSString *config = [fm.applicationSupportDirectory stringByAppendingString:g_ConfigDirPostfix];
    if( ![fm fileExistsAtPath:config] )
        [fm createDirectoryAtPath:config withIntermediateDirectories:true attributes:nil error:nil];
    m_ConfigDirectory = config.fileSystemRepresentationSafe;
    
    NSString *state = [fm.applicationSupportDirectory stringByAppendingString:g_StateDirPostfix];
    if( ![fm fileExistsAtPath:state] )
        [fm createDirectoryAtPath:state withIntermediateDirectories:true attributes:nil error:nil];
    m_StateDirectory = state.fileSystemRepresentationSafe;
    
    const auto bundle = NSBundle.mainBundle;
    const auto config_defaults_path = [bundle pathForResource:@"Config"
                                                       ofType:@"json"].fileSystemRepresentationSafe;
    const auto state_defaults_path = [bundle pathForResource:@"State"
                                                      ofType:@"json"].fileSystemRepresentationSafe;
    g_Config = new GenericConfig(config_defaults_path, self.configDirectory + "Config.json");
    g_State  = new GenericConfig(state_defaults_path, self.stateDirectory + "State.json");
    
    atexit([]{
        // this callback is quite brutal, but works well. may need to find some more gentle approach
        GlobalConfig().Commit();
        StateConfig().Commit();
    });
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return NO;
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    if( NCAppDelegate.me.isRunningTests ) {
        completionHandler(nil, nil);
        return;
    }

    NSWindow *window = nil;
    if( [identifier isEqualToString:NCMainWindow.defaultIdentifier] )
        window = [g_Me allocateMainWindowRestoredBySystem].window;
    completionHandler(window, nil);
}

- (IBAction)onMainMenuNewWindow:(id)sender
{
    auto ctrl = [self allocateMainWindowRestoredManually];
    [ctrl showWindow:self];
}

- (void) addMainWindow:(NCMainWindowController*) _wnd
{
    m_MainWindows.push_back(_wnd);
}

- (void) removeMainWindow:(NCMainWindowController*) _wnd
{
    auto it = find(begin(m_MainWindows), end(m_MainWindows), _wnd);
    if(it != end(m_MainWindows))
        m_MainWindows.erase(it);
}

- (void)windowWillClose:(NSNotification*)aNotification
{
    if( auto main_wnd = objc_cast<NCMainWindow>(aNotification.object) )
        if( auto main_ctrl = objc_cast<NCMainWindowController>(main_wnd.delegate) ) {
            dispatch_to_main_queue([=]{
                [self removeMainWindow:main_ctrl];
            });
        }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    bool has_running_ops = false;
    auto controllers = self.mainWindowControllers;
    for( const auto wincont: controllers )
        if( !wincont.operationsPool.Empty() ) {
            has_running_ops = true;
            break;
        }
        else if(wincont.terminalState && wincont.terminalState.isAnythingRunning) {
            has_running_ops = true;
            break;
        }
    
    if( has_running_ops ) {
        if( !AskToExitWithRunningOperations() )
            return NSTerminateCancel;

        for( const auto wincont : controllers ) {
            wincont.operationsPool.StopAndWaitForShutdown();
            [wincont.terminalState terminate];
        }
    }
    
    // last cleanup before shutting down here:
    if( m_Favorites  )
        m_Favorites->StoreData( StateConfig(), "filePanel.favorites" );
    
    return NSTerminateNow;
}

- (IBAction)OnMenuSendFeedback:(id)sender
{
    FeedbackManager::Instance().EmailFeedback();
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return true;
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)sender
{
    if( !m_FinishedLaunching || m_IsRunningTests )
        return false;
    
    if( !self.mainWindowControllers.empty() )
        return true;
  
    [self onMainMenuNewWindow:sender];
    
    return true;
}


- (bool) processLicenseFileActivation:(NSArray<NSString *> *)_filenames
{
    static const auto nc_license_extension = "."s + ActivationManager::LicenseFileExtension();
    
    if( _filenames.count != 1)
        return false;
    
    for( NSString *pathstring in _filenames )
        if( auto fs = pathstring.fileSystemRepresentationSafe ) {
            if constexpr( ActivationManager::Type() == ActivationManager::Distribution::Trial ) {
                if( _filenames.count == 1 && path(fs).extension() == nc_license_extension ) {
                    string p = fs;
                    dispatch_to_main_queue([=]{
                        [self processProvidedLicenseFile:p];
                    });
                    return true;
                }
            }
        }
    return false;
}

- (void)drainFilesToOpen
{
    if( m_FilesToOpen.count == 0 )
        return;
    
    if( ![self processLicenseFileActivation:m_FilesToOpen] )
        self.servicesHandler.OpenFiles(m_FilesToOpen);

    [m_FilesToOpen removeAllObjects];
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    [m_FilesToOpen addObjectsFromArray:@[filename]];
    dispatch_to_main_queue_after(250ms, []{ [g_Me drainFilesToOpen]; });
    return true;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray<NSString *> *)filenames
{
    [m_FilesToOpen addObjectsFromArray:filenames];
    dispatch_to_main_queue_after(250ms, []{ [g_Me drainFilesToOpen]; });
    [NSApp replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

- (void) processProvidedLicenseFile:(const string&)_path
{
    const bool valid_and_installed = ActivationManager::Instance().ProcessLicenseFile(_path);
    if( valid_and_installed ) {
        ThankUserForBuyingALicense();
        [self updateMainMenuFeaturesByVersionAndState];
        self.dock.SetUnregisteredBadge( false );
        GA().PostEvent("Licensing", "Buy", "Successful external license activation");
    }
}

- (IBAction)OnActivateExternalLicense:(id)sender
{
    if( auto path = AskUserForLicenseFile() )
        [self processProvidedLicenseFile:*path];
}

- (IBAction)OnPurchaseExternalLicense:(id)sender
{
    const auto url = [NSURL URLWithString:@"http://magnumbytes.com/redirectlinks/buy_license"];
    [NSWorkspace.sharedWorkspace openURL:url];
    GA().PostEvent("Licensing", "Buy", "Go to 3rd party registrator");
}

- (IBAction)OnPurchaseProFeaturesInApp:(id)sender
{
    [m_AppStoreHelper showProFeaturesWindow];
}

- (IBAction)OnRestoreInAppPurchases:(id)sender
{
    [m_AppStoreHelper askUserToRestorePurchases];
}

- (void)openFolderService:(NSPasteboard *)pboard userData:(NSString *)data error:(__strong NSString **)error
{
    self.servicesHandler.OpenFolder(pboard, data, error);
}

- (void)revealItemService:(NSPasteboard *)pboard userData:(NSString *)data error:(__strong NSString **)error
{
    self.servicesHandler.RevealItem(pboard, data, error);
}

- (void)OnPreferencesCommand:(id)sender
{
    ShowPreferencesWindow();
}

- (IBAction)OnShowHelp:(id)sender
{
    const auto url = [NSBundle.mainBundle URLForResource:@"Help" withExtension:@"pdf"];
    [NSWorkspace.sharedWorkspace openURL:url];
    GA().PostEvent("Help", "Click", "Open Help");
}

- (IBAction)onMainMenuPerformGoToProductForum:(id)sender
{
    const auto url = [NSURL URLWithString:@"http://magnumbytes.com/forum/"];
    [NSWorkspace.sharedWorkspace openURL:url];
    GA().PostEvent("Help", "Click", "Visit Forum");
}

- (IBAction)OnMenuToggleAdminMode:(id)sender
{
    if( RoutedIO::Instance().Enabled() )
        RoutedIO::Instance().TurnOff();
    else {
        GA().PostScreenView("Admin Mode");
        
        const auto turned_on = RoutedIO::Instance().TurnOn();
        if( !turned_on )
            WarnAboutFailingToAccessPriviledgedHelper();
    }

    self.dock.SetAdminBadge( RoutedIO::Instance().Enabled() );
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    
    IF_MENU_TAG("menu.nimble_commander.toggle_admin_mode") {
        bool enabled = RoutedIO::Instance().Enabled();
        item.title = enabled ?
            NSLocalizedString(@"Disable Admin Mode", "Menu item title for disabling an admin mode") :
            NSLocalizedString(@"Enable Admin Mode", "Menu item title for enabling an admin mode");
        return true;
    }
    
    return true;
}

- (GenericConfigObjC*) config
{
    static auto global_config_bridge = [[GenericConfigObjC alloc] initWithConfig:g_Config];
    return global_config_bridge;
}

- (ExternalToolsStorage&) externalTools
{
    static auto i = new ExternalToolsStorage(g_ConfigExternalToolsList);
    return *i;
}

- (const shared_ptr<nc::panel::PanelViewLayoutsStorage>&) panelLayouts
{
    static auto i = make_shared<nc::panel::PanelViewLayoutsStorage>(g_ConfigLayoutsList);
    return i;
}

- (ThemesManager&) themesManager
{
    static auto i = new ThemesManager(g_ConfigSelectedThemes, g_ConfigThemesList);
    return *i;
}

- (ExternalEditorsStorage&) externalEditorsStorage
{
    static auto i = new ExternalEditorsStorage(g_ConfigExtEditorsList);
    return *i;
}

- (const shared_ptr<nc::panel::FavoriteLocationsStorage>&) favoriteLocationsStorage
{
    static once_flag once;
    call_once(once, [&]{
        using t = nc::panel::FavoriteLocationsStorageImpl;
        m_Favorites = make_shared<t>(StateConfig(), "filePanel.favorites");
    });
    
    static const shared_ptr<nc::panel::FavoriteLocationsStorage> inst = m_Favorites;
    return inst;
}

- (bool) askToResetDefaults
{
    if( AskUserToResetDefaults() ) {
        ResetDefaults();
        return true;
    }
    return false;
}

- (void) addInternalViewerWindow:(InternalViewerWindowController*)_wnd
{
    LOCK_GUARD(m_ViewerWindowsLock) {
        m_ViewerWindows.emplace_back(_wnd);
    }
}

- (void) removeInternalViewerWindow:(InternalViewerWindowController*)_wnd
{
    LOCK_GUARD(m_ViewerWindowsLock) {
        auto i = find(begin(m_ViewerWindows), end(m_ViewerWindows), _wnd);
        if( i != end(m_ViewerWindows) )
            m_ViewerWindows.erase(i);
    }
}

- (InternalViewerWindowController*) findInternalViewerWindowForPath:(const string&)_path onVFS:(const VFSHostPtr&)_vfs
{
    LOCK_GUARD(m_ViewerWindowsLock) {
        auto i = find_if(begin(m_ViewerWindows), end(m_ViewerWindows), [&](auto v){
            return v.internalViewerController.filePath == _path &&
            v.internalViewerController.fileVFS == _vfs;
        });
        return i != end(m_ViewerWindows) ? *i : nil;
    }
    return nil;
}

- (IBAction)onMainMenuPerformShowVFSListAction:(id)sender
{
    static __weak VFSListWindowController *existing_window = nil;
    if( auto w = (VFSListWindowController*)existing_window  )
        [w show];
    else {
        auto window = [[VFSListWindowController alloc] initWithVFSManager:self.vfsInstanceManager];
        [window show];
        existing_window = window;
    }
}

- (IBAction)onMainMenuPerformShowFavorites:(id)sender
{
    static __weak FavoritesWindowController *existing_window = nil;
    if( auto w = (FavoritesWindowController*)existing_window  ) {
        [w show];
        return ;
    }
    auto storage = []()->nc::panel::FavoriteLocationsStorage& {
        return *NCAppDelegate.me.favoriteLocationsStorage;
    };
    FavoritesWindowController *window = [[FavoritesWindowController alloc]
                                         initWithFavoritesStorage:storage];
    auto provide_panel = []() -> vector<pair<VFSHostPtr, string>> {
        vector< pair<VFSHostPtr, string> > panel_paths;
        for( const auto &ctr: NCAppDelegate.me.mainWindowControllers ) {
            auto state = ctr.filePanelsState;
            auto paths = state.filePanelsCurrentPaths;
            for( const auto &p:paths )
                panel_paths.emplace_back( get<1>(p), get<0>(p) );
        }
        return panel_paths;
    };
    window.provideCurrentUniformPaths = provide_panel;
    
    [window show];
    existing_window = window;
}

- (const shared_ptr<NetworkConnectionsManager> &)networkConnectionsManager
{
    static const auto mgr = make_shared<ConfigBackedNetworkConnectionsManager>
        (self.configDirectory);
    static const shared_ptr<NetworkConnectionsManager> int_ptr = mgr;
    return int_ptr;
}

- (nc::ops::AggregateProgressTracker&) operationsProgressTracker
{
    static const auto apt = [self]{
        const auto apt = make_shared<nc::ops::AggregateProgressTracker>();
        apt->SetProgressCallback([](double _progress){
            g_Me.dock.SetProgress( _progress );
        });
        return apt;
    }();
    return *apt.get();
}

- (nc::core::Dock&) dock
{
    static const auto instance = new nc::core::Dock;
    return *instance;
}

- (nc::core::VFSInstanceManager&)vfsInstanceManager
{
    static const auto instance = new nc::core::VFSInstanceManagerImpl;
    return *instance;
}

- (const shared_ptr<nc::panel::ClosedPanelsHistory>&)closedPanelsHistory
{
    static const auto impl = make_shared<nc::panel::ClosedPanelsHistoryImpl>();
    static const shared_ptr<nc::panel::ClosedPanelsHistory> history = impl;
    return history;
}

- (NCMainWindowController*)windowForExternalRevealRequest
{
    NCMainWindowController *target_window = nil;
    for( NSWindow *wnd in NSApplication.sharedApplication.orderedWindows )
        if( auto wc =  objc_cast<NCMainWindowController>(wnd.windowController) )
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

- (nc::core::ServicesHandler&)servicesHandler
{
    auto window_locator = []{
        return [g_Me windowForExternalRevealRequest];
    };
    static nc::core::ServicesHandler handler(window_locator);
    return handler;
}

@end
