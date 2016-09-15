//
//  AppDelegate.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Sparkle/Sparkle.h>
#include <Habanero/CommonPaths.h>
#include <Habanero/CFDefaultsCPP.h>
#include <Habanero/algo.h>
#include <Utility/NSMenu+Hierarchical.h>
#include <Utility/NativeFSManager.h>
#include <Utility/PathManip.h>
#include <Utility/FunctionKeysPass.h>
#include "3rd_party/NSFileManager+DirectoryLocations.h"
#include "3rd_party/RHPreferences/RHPreferences/RHPreferences.h"
#include "vfs/vfs_native.h"
#include "vfs/vfs_arc_la.h"
#include "vfs/vfs_arc_unrar.h"
#include "vfs/vfs_ps.h"
#include "vfs/vfs_xattr.h"
#include "vfs/vfs_net_ftp.h"
#include "vfs/vfs_net_sftp.h"
#include "States/Terminal/MainWindowTerminalState.h"
#include "AppDelegate.h"
#include "MainWindowController.h"
#include "Operations/OperationsController.h"
#include "../NimbleCommander/Preferences/Preferences.h"
#include "TemporaryNativeFileStorage.h"
#include "ActionsShortcutsManager.h"
#include "MainWindowFilePanelState.h"
#include "SandboxManager.h"
#include "MASAppInstalledChecker.h"
#include "TrialWindowController.h"
#include "RoutedIO.h"
#include "Config.h"
#include "AppDelegate+Migration.h"
#include "../NimbleCommander/Bootstrap/ActivationManager.h"
#include "GoogleAnalytics.h"
#include "../NimbleCommander/States/FilePanels/ExternalToolsSupport.h"
#include "../NimbleCommander/Viewer/InternalViewerController.h"
#include "../NimbleCommander/Viewer/InternalViewerWindowController.h"
#include "../NimbleCommander/GeneralUI/VFSListWindowController.h"
#include "../NimbleCommander/Core/FeedbackManager.h"

#include "AppStoreHelper.h"

static SUUpdater *g_Sparkle = nil;

static auto g_ConfigDirPostfix = @"/Config/";
static auto g_StateDirPostfix = @"/State/";

static GenericConfig *g_Config = nullptr;
static GenericConfig *g_State = nullptr;

static const auto g_ConfigGeneralSkin = "general.skin";
static const auto g_ConfigRestoreLastWindowState = "filePanel.general.restoreLastWindowState";
static const auto g_ConfigForceFn = "general.alwaysUseFnKeysAsFunctional";
static const auto g_ConfigExternalToolsList = "externalTools.tools_v1";

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

static string cwd()
{
    char cwd[MAXPATHLEN];
    getcwd(cwd, MAXPATHLEN);
    return cwd;
}

static optional<string> AskUserForLicenseFile()
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.resolvesAliases = true;
    panel.canChooseDirectories = false;
    panel.canChooseFiles = true;
    panel.allowsMultipleSelection = false;
    panel.showsHiddenFiles = true;
    panel.allowedFileTypes = @[ [NSString stringWithUTF8StdString:ActivationManager::LicenseFileExtension()] ];
    panel.allowsOtherFileTypes = false;
    panel.directoryURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithUTF8StdString:CommonPaths::Downloads()] isDirectory:true];
    if( [panel runModal] == NSFileHandlingPanelOKButton )
        if(panel.URL != nil) {
            string path = panel.URL.path.fileSystemRepresentationSafe;
            return path;
        }
    return nullopt;
}

static bool AskUserToResetDefaults()
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Are you sure you want to reset settings to defaults?", "Asking user for confirmation on erasing custom settings - message");
    alert.informativeText = NSLocalizedString(@"This will erase all your custom settings.", "Asking user for confirmation on erasing custom settings - informative text");
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    [alert.buttons objectAtIndex:0].keyEquivalent = @"";
    if( [alert runModal] == NSAlertFirstButtonReturn ) {
        [NSUserDefaults.standardUserDefaults removePersistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
        [NSUserDefaults.standardUserDefaults synchronize];
        GlobalConfig().ResetToDefaults();
        StateConfig().ResetToDefaults();
        GlobalConfig().Commit();
        StateConfig().Commit();
        return  true;
    }
    return false;
}

static bool AskUserToProvideUsageStatistics()
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Please help us to improve the product", "Asking user to provide anonymous usage information - message");
    alert.informativeText = NSLocalizedString(@"Would you like to send anonymous usage statistics to the developer? None of your personal data would be collected.", "Asking user to provide anonymous usage information - informative text");
    [alert addButtonWithTitle:NSLocalizedString(@"Send", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Don't send", "")];
    return [alert runModal] == NSAlertFirstButtonReturn;
}

static NSProgressIndicator *AddDockProgressIndicator( NSDockTile *_dock )
{
    NSImageView *iv = [NSImageView new];
    iv.image = NSApplication.sharedApplication.applicationIconImage;
    _dock.contentView = iv;
    
    NSProgressIndicator *progress = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 2, _dock.size.width, 18)];
    progress.style = NSProgressIndicatorBarStyle;
    progress.indeterminate = NO;
    progress.bezeled = true;
    progress.minValue = 0;
    progress.maxValue = 1;
    progress.hidden = true;
    [iv addSubview:progress];

    return progress;
}

static AppDelegate *g_Me = nil;

@implementation AppDelegate
{
    vector<MainWindowController *>              m_MainWindows;
    vector<InternalViewerWindowController*>     m_ViewerWindows;
    spinlock                                    m_ViewerWindowsLock;
    RHPreferencesWindowController *m_PreferencesController;
    ApplicationSkin     m_Skin;
    NSProgressIndicator *m_ProgressIndicator;
    NSDockTile          *m_DockTile;
    double              m_AppProgress;
    bool                m_IsRunningTests;
    string              m_StartupCWD;
    string              m_SupportDirectory;
    string              m_ConfigDirectory;
    string              m_StateDirectory;
    vector<GenericConfig::ObservationTicket> m_ConfigObservationTickets;
    AppStoreHelper *m_AppStoreHelper;
    upward_flag         m_FinishedLaunching;
}

@synthesize isRunningTests = m_IsRunningTests;
@synthesize startupCWD = m_StartupCWD;
@synthesize skin = m_Skin;
@synthesize mainWindowControllers = m_MainWindows;
@synthesize configDirectory = m_ConfigDirectory;
@synthesize stateDirectory = m_StateDirectory;
@synthesize supportDirectory = m_SupportDirectory;

- (id) init
{
    self = [super init];
    if(self) {
        g_Me = self;
        m_StartupCWD = cwd();
        m_IsRunningTests = (NSClassFromString(@"XCTestCase") != nil);
        m_AppProgress = -1;
        m_Skin = ApplicationSkin::Modern;

        if( ActivationManager::ForAppStore() &&
           ![NSFileManager.defaultManager fileExistsAtPath:NSBundle.mainBundle.appStoreReceiptURL.path] ) {
            NSLog(@"no receipt - exit the app with code 173");
            exit(173);
        }
        
        const auto erase_mask = NSAlphaShiftKeyMask | NSShiftKeyMask | NSAlternateKeyMask | NSCommandKeyMask;
        if( (NSEvent.modifierFlags & erase_mask) == erase_mask )
            if( AskUserToResetDefaults() )
                exit(0);
        
        m_SupportDirectory = EnsureTrailingSlash(NSFileManager.defaultManager.applicationSupportDirectory.fileSystemRepresentationSafe);
        
        [self setupConfigs];
        
        [self reloadSkinSetting];
        m_ConfigObservationTickets.emplace_back( GlobalConfig().Observe(g_ConfigGeneralSkin, []{ [AppDelegate.me reloadSkinSetting]; }) );
        
        [self migrateViewerHistory_1_1_3_to_1_1_5];        
    }
    return self;
}

+ (AppDelegate*) me
{
    return g_Me;
}

- (void) reloadSkinSetting
{
    auto new_skin = (ApplicationSkin)GlobalConfig().GetInt(g_ConfigGeneralSkin);
    if( new_skin == ApplicationSkin::Modern || new_skin == ApplicationSkin::Classic ) {
        [self willChangeValueForKey:@"skin"];
        m_Skin = new_skin;
        [self didChangeValueForKey:@"skin"];
        
        GoogleAnalytics::Instance().PostEvent("Appearance",
                                              "Set",
                                              new_skin == ApplicationSkin::Classic ? "Classic" : "Modern");
    }
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    // modules initialization
    VFSFactory::Instance().RegisterVFS(       VFSNativeHost::Meta() );
    VFSFactory::Instance().RegisterVFS(           VFSPSHost::Meta() );
    VFSFactory::Instance().RegisterVFS(      VFSNetSFTPHost::Meta() );
    VFSFactory::Instance().RegisterVFS(       VFSNetFTPHost::Meta() );
    VFSFactory::Instance().RegisterVFS(      VFSArchiveHost::Meta() );
    VFSFactory::Instance().RegisterVFS( VFSArchiveUnRARHost::Meta() );
    VFSFactory::Instance().RegisterVFS(        VFSXAttrHost::Meta() );
    
    NativeFSManager::Instance();
    FeedbackManager::Instance();
    
    [self updateMainMenuFeaturesByVersionAndState];
    
    // update menu with current shortcuts layout
    ActionsShortcutsManager::Instance().SetMenuShortCuts([NSApp mainMenu]);
  
    bool showed_modal_dialog = false;
    if( ActivationManager::Instance().Sandboxed() ) {
        auto &sm = SandboxManager::Instance();
        if( sm.Empty() ) {
            sm.AskAccessForPathSync(CommonPaths::Home(), false);
            showed_modal_dialog = true;
            if( m_MainWindows.empty() )
                [self AllocateNewMainWindow];
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
        GoogleAnalytics::Instance().UpdateEnabledStatus();
    }
}

- (void)updateMainMenuFeaturesByVersionAndState
{
    static NSMenu *original_menu_state = [NSApp.mainMenu copy];
    
    // disable some features available in menu by configuration limitation
    auto tag_from_lit       = [ ](const string &s) { return ActionsShortcutsManager::Instance().TagFromAction(s);             };
    auto current_menuitem   = [&](const string &s) { return [NSApp.mainMenu itemWithTagHierarchical:tag_from_lit(s)];         };
    auto initial_menuitem   = [&](const string &s) { return [original_menu_state itemWithTagHierarchical:tag_from_lit(s)];    };
    auto hide               = [&](const string &s) {
        auto item = current_menuitem(s);
        item.alternate = false;
        item.hidden = true;
    };
    auto enable             = [&](const string &_action, bool _enabled) {
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
    enable( "menu.command.system_overview",     am.HasBriefSystemOverview() );
    enable( "menu.command.file_attributes",     am.HasUnixAttributesEditing() );
    enable( "menu.command.volume_information",  am.HasDetailedVolumeInformation() );
    enable( "menu.command.batch_rename",        am.HasBatchRename() );
    enable( "menu.command.internal_viewer",     am.HasInternalViewer() );
    enable( "menu.command.compress",            am.HasCompressionOperation() );
    enable( "menu.command.compress_here",       am.HasCompressionOperation() );
    enable( "menu.command.link_create_soft",    am.HasLinksManipulation() );
    enable( "menu.command.link_create_hard",    am.HasLinksManipulation() );
    enable( "menu.command.link_edit",           am.HasLinksManipulation());
    enable( "menu.command.open_xattr",          am.HasXAttrFS() );
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    m_FinishedLaunching.toggle();
    
    if( !m_IsRunningTests && m_MainWindows.empty() )
        [self applicationOpenUntitledFile:NSApp]; // if there's no restored windows - we'll create a freshly new one
    
    NSApp.servicesProvider = self;
    [NSApp registerServicesMenuSendTypes:@[NSFilenamesPboardType, (__bridge NSString *)kUTTypeFileURL]
                             returnTypes:@[]]; // pasteboard types provided by PanelController
    NSUpdateDynamicServices();
    
    // init app dock progress bar
    m_DockTile = NSApplication.sharedApplication.dockTile;
    m_ProgressIndicator = AddDockProgressIndicator(m_DockTile);
    
    // calling modules running in background
    TemporaryNativeFileStorage::Instance(); // starting background purging implicitly
    
    // Non-MAS version stuff below:
    if( !ActivationManager::ForAppStore() && !self.isRunningTests ) {
        if( ActivationManager::Instance().ShouldShowTrialNagScreen() ) // check if we should show a nag screen
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
                GoogleAnalytics::Instance().PostEvent("Licensing", "Buy", "Pro features IAP purchased");
            }
        };
    }
    
    // accessibility stuff for NonMAS version
    if( ActivationManager::Type() == ActivationManager::Distribution::Trial &&
        GlobalConfig().GetBool(g_ConfigForceFn) ) {
        FunctionalKeysPass::Instance().Enable();
    }
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
    
    g_Config = new GenericConfig([NSBundle.mainBundle pathForResource:@"Config" ofType:@"json"].fileSystemRepresentationSafe, self.configDirectory + "Config.json");
    g_State  = new GenericConfig([NSBundle.mainBundle pathForResource:@"State" ofType:@"json"].fileSystemRepresentationSafe, self.stateDirectory + "State.json");
    
    atexit([]{ // this callback is quite brutal, but works well. may need to find some more gentle approach
        GlobalConfig().Commit();
        StateConfig().Commit();
    });
}

- (void) updateDockTileBadge
{
    // currently considering only admin mode for setting badge info
    bool admin = RoutedIO::Instance().Enabled();
    m_DockTile.badgeLabel = admin ? @"ADMIN" : @"";
}

- (double) progress
{
    return m_AppProgress;
}

- (void) setProgress:(double)_progress
{
    if(_progress == m_AppProgress)
        return;
    
    if(_progress >= 0.0 && _progress <= 1.0) {
        m_ProgressIndicator.doubleValue = _progress;
        m_ProgressIndicator.hidden = false;
    }
    else {
        m_ProgressIndicator.hidden = true;
    }
    
    m_AppProgress = _progress;
    
    [m_DockTile display];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return NO;
}

// AllocateNewMainWindow and NewWindow are pretty similar, it's bad they are different methods
- (MainWindowController*)AllocateNewMainWindow
{
    MainWindowController *mwc = [MainWindowController new];
    m_MainWindows.push_back(mwc);    
    [mwc showWindow:self];
    return mwc;
}

- (IBAction)NewWindow:(id)sender
{
    MainWindowController *mwc = [MainWindowController new];
    [mwc restoreDefaultWindowStateFromLastOpenedWindow];
    m_MainWindows.push_back(mwc);
    [mwc showWindow:self];
}

- (void) RemoveMainWindow:(MainWindowController*) _wnd
{
    auto it = find(begin(m_MainWindows), end(m_MainWindows), _wnd);
    if(it != end(m_MainWindows))
        m_MainWindows.erase(it);
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    bool has_running_ops = false;
    for (MainWindowController *wincont: m_MainWindows)
        if (wincont.OperationsController.OperationsCount > 0) {
            has_running_ops = true;
            break;
        }
        else if(wincont.terminalState && wincont.terminalState.isAnythingRunning) {
            has_running_ops = true;
            break;
        }
    
    if (has_running_ops) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"The application has running operations. Do you want to stop all operations and quit?", "Asking user for quitting app with activity");
        [alert addButtonWithTitle:NSLocalizedString(@"Stop and Quit", "Asking user for quitting app with activity - confirmation")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
        NSInteger result = [alert runModal];
        
        // If cancel is pressed.
        if (result == NSAlertSecondButtonReturn) return NSTerminateCancel;
        
        for (MainWindowController *wincont : m_MainWindows) {
            [wincont.OperationsController Stop];
            [wincont.terminalState Terminate];
        }
    }
    
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
    
    if( m_MainWindows.empty() ) {
        auto mw = [self AllocateNewMainWindow];
        if( GlobalConfig().GetBool(g_ConfigRestoreLastWindowState) )
            [mw restoreDefaultWindowStateFromConfig];
    }
    return true;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    [self application:sender openFiles:@[filename]];;
    return true;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray<NSString *> *)filenames
{
    vector<string> paths;
    for( NSString *pathstring in filenames )
        if( auto fs = pathstring.fileSystemRepresentationSafe ) {
            static const auto nc_license_extension = "."s + ActivationManager::LicenseFileExtension();
            if( filenames.count == 1 && path(fs).extension() == nc_license_extension ) {
                string p = fs;
                dispatch_to_main_queue([=]{ [self processProvidedLicenseFile:p]; });
                return;
            }
            
            paths.emplace_back( fs );
        }
    
    if( !paths.empty() )
        [self doRevealNativeItems:paths];
}

- (void) processProvidedLicenseFile:(const string&)_path
{
    const bool valid_and_installed = ActivationManager::Instance().ProcessLicenseFile(_path);
    if( valid_and_installed ) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.icon = [NSImage imageNamed:@"checked_icon"];
        alert.messageText       = NSLocalizedString(@"__THANKS_FOR_REGISTER_MESSAGE", "Message to thank user for buying");
        alert.informativeText   = NSLocalizedString(@"__THANKS_FOR_REGISTER_INFORMATIVE", "Informative text to thank user for buying");
        [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
        [alert runModal];
        
        [self updateMainMenuFeaturesByVersionAndState];
        GoogleAnalytics::Instance().PostEvent("Licensing", "Buy", "Successful external license activation");
    }
}

- (IBAction)OnActivateExternalLicense:(id)sender
{
    if( auto path = AskUserForLicenseFile() )
        [self processProvidedLicenseFile:*path];
}

- (IBAction)OnPurchaseExternalLicense:(id)sender
{
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"http://magnumbytes.com/redirectlinks/buy_license"]];
    GoogleAnalytics::Instance().PostEvent("Licensing", "Buy", "Go to 3rd party registrator");
}

- (IBAction)OnPurchaseProFeaturesInApp:(id)sender
{
    [m_AppStoreHelper askUserToBuyProFeatures];
    GoogleAnalytics::Instance().PostEvent("Licensing", "Buy", "Buy Pro features IAP");
}

- (IBAction)OnRestoreInAppPurchases:(id)sender
{
    [m_AppStoreHelper askUserToRestorePurchases];
    GoogleAnalytics::Instance().PostEvent("Licensing", "Buy", "Restore IAP purchases");
}

- (void) doRevealNativeItems:(const vector<string>&)_path
{
    // TODO: need to implement handling muliple directory paths in the future
    // grab first common directory and all corresponding items in it.
    string directory;
    vector<string> filenames;
    for( auto &i:_path ) {
        if( directory.empty() )
            directory = path(i).parent_path().native();
        
        if( !i.empty() &&
            i.front() == '/' &&
            i != "/"
           )
            filenames.emplace_back( path(i).filename().native() );
    }
    
    if( filenames.empty() )
        return;

    // find window to ask
    NSWindow *target_window = nil;
    for( NSWindow *wnd in NSApplication.sharedApplication.orderedWindows )
        if(wnd != nil &&
           objc_cast<MainWindowController>(wnd.windowController) != nil) {
            target_window = wnd;
            break;
        }
    
    if(!target_window) {
        [self AllocateNewMainWindow];
        target_window = [m_MainWindows.back() window];
    }

    if(target_window) {
        [target_window makeKeyAndOrderFront:self];
        MainWindowController *contr = (MainWindowController*)[target_window windowController];
        [contr.filePanelsState revealEntries:filenames inDirectory:directory];
    }
}

- (void)IClicked:(NSPasteboard *)pboard userData:(NSString *)data error:(__strong NSString **)error
{
    // extract file paths
    vector<string> paths;
    for( NSPasteboardItem *item in pboard.pasteboardItems )
        if( NSString *urlstring = [item stringForType:@"public.file-url"] ) {
            if( NSURL *url = [NSURL URLWithString:urlstring] )
                if( NSString *unixpath = url.path )
                    if( auto fs = unixpath.fileSystemRepresentation  )
                        paths.emplace_back( fs );
        }
        else if( NSString *path_string = [item stringForType:@"NSFilenamesPboardType"]  ) {
            if( auto fs = path_string.fileSystemRepresentation  )
                paths.emplace_back( fs );
        }

    if( !paths.empty() )
        [self doRevealNativeItems:paths];
}

- (void)OnPreferencesCommand:(id)sender
{
    if( !m_PreferencesController ){
        auto tools_storage = [=]()->ExternalToolsStorage&{return self.externalTools;};
        NSMutableArray *controllers = [NSMutableArray new];
        [controllers addObject:[PreferencesWindowGeneralTab new]];
        [controllers addObject:[PreferencesWindowPanelsTab new]];
        if( ActivationManager::Instance().HasInternalViewer() )
            [controllers addObject:[PreferencesWindowViewerTab new]];
        [controllers addObject:[PreferencesWindowExternalEditorsTab new]];
        if( ActivationManager::Instance().HasTerminal() )
            [controllers addObject:[PreferencesWindowTerminalTab new]];
        [controllers addObject:[[PreferencesWindowHotkeysTab alloc] initWithToolsStorage:tools_storage]];
        if( ActivationManager::Instance().HasExternalTools() )
            [controllers addObject:[[PreferencesWindowToolsTab alloc] initWithToolsStorage:tools_storage]];
        
        m_PreferencesController = [[RHPreferencesWindowController alloc] initWithViewControllers:controllers
                                                                                        andTitle:@"Preferences"];
    }
    
    [m_PreferencesController showWindow:self];
    GoogleAnalytics::Instance().PostScreenView("Preferences Window");
}

- (IBAction)OnShowHelp:(id)sender
{
    NSString *path = [NSBundle.mainBundle pathForResource:@"Help" ofType:@"pdf"];
    [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:path]];
}

- (IBAction)OnMenuToggleAdminMode:(id)sender
{
    if( RoutedIO::Instance().Enabled() )
        RoutedIO::Instance().TurnOff();
    else {
        bool result = RoutedIO::Instance().TurnOn();
        if( !result ) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = NSLocalizedString(@"Failed to access the privileged helper.", "Information that toggling admin mode on has failed");
            [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
            [alert runModal];
        }
    }

    [self updateDockTileBadge];
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
    static GenericConfigObjC *global_config_bridge = [[GenericConfigObjC alloc] initWithConfig:g_Config];
    return global_config_bridge;
}

- (ExternalToolsStorage&) externalTools
{
    static ExternalToolsStorage* i = new ExternalToolsStorage(g_ConfigExternalToolsList);
    return *i;
}

- (bool) askToResetDefaults
{
    return AskUserToResetDefaults();
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
        VFSListWindowController *window = [[VFSListWindowController alloc] init];
        [window show];
        existing_window = window;
    }
}

@end
