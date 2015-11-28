//
//  AppDelegate.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Sparkle/Sparkle.h>
#import <Habanero/CommonPaths.h>
#import "3rd_party/NSFileManager+DirectoryLocations.h"
#import "3rd_party/RHPreferences/RHPreferences/RHPreferences.h"
#include "vfs/vfs_native.h"
#include "vfs/vfs_arc_la.h"
#include "vfs/vfs_arc_unrar.h"
#include "vfs/vfs_ps.h"
#include "vfs/vfs_xattr.h"
#include "vfs/vfs_net_ftp.h"
#include "vfs/vfs_net_sftp.h"
#import "AppDelegate.h"
#import "MainWindowController.h"
#import "Operations/OperationsController.h"
#import "Common.h"
#import "chained_strings.h"
#import "PreferencesWindowGeneralTab.h"
#import "PreferencesWindowPanelsTab.h"
#import "PreferencesWindowViewerTab.h"
#import "PreferencesWindowExternalEditorsTab.h"
#import "PreferencesWindowTerminalTab.h"
#import "PreferencesWindowHotkeysTab.h"
#import "TemporaryNativeFileStorage.h"
#import "MainWindowTerminalState.h"
#import "NativeFSManager.h"
#import "ActionsShortcutsManager.h"
#import "MainWindowFilePanelState.h"
#import "SandboxManager.h"
#import "MASAppInstalledChecker.h"
#import "TrialWindowController.h"
#import "RoutedIO.h"
#import "sysinfo.h"
#import "AppStoreRatings.h"

static SUUpdater *g_Sparkle = nil;

@implementation AppDelegate
{
    vector<MainWindowController *> m_MainWindows;
    RHPreferencesWindowController *m_PreferencesController;
    ApplicationSkin     m_Skin;
    NSProgressIndicator *m_ProgressIndicator;
    NSDockTile          *m_DockTile;
    double              m_AppProgress;
    bool                m_IsRunningTests;
    string              m_StartupCWD;
    string              m_ConfigDirectory;
}

@synthesize isRunningTests = m_IsRunningTests;
@synthesize startupCWD = m_StartupCWD;
@synthesize skin = m_Skin;
@synthesize mainWindowControllers = m_MainWindows;
@synthesize configDirectory = m_ConfigDirectory;

- (id) init
{
    self = [super init];
    if(self) {
        char cwd[MAXPATHLEN];
        getcwd(cwd, MAXPATHLEN);
        m_StartupCWD = cwd;
        
        m_IsRunningTests = (NSClassFromString(@"XCTestCase") != nil);
        m_AppProgress = -1;
        
        NSString *defaults_file = [NSBundle.mainBundle pathForResource:@"Defaults" ofType:@"plist"];
        NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaults_file];
        [NSUserDefaults.standardUserDefaults registerDefaults:defaults];
        auto erase_mask = NSAlphaShiftKeyMask | NSShiftKeyMask | NSAlternateKeyMask | NSCommandKeyMask;
        if((NSEvent.modifierFlags & erase_mask) == erase_mask) {
            [self askToResetDefaults];
            exit(0);
        }
        
        [self setupConfigDirectory];
        
        m_Skin = (ApplicationSkin)[NSUserDefaults.standardUserDefaults integerForKey:@"Skin"];
        assert(m_Skin == ApplicationSkin::Modern || m_Skin == ApplicationSkin::Classic);
        [NSUserDefaults.standardUserDefaults addObserver:self
                                              forKeyPath:@"Skin"
                                                 options:0
                                                 context:NULL];
    }
    return self;
}

- (void)dealloc
{
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:@"Skin" context:NULL];
}

+ (AppDelegate*) me
{
    static AppDelegate *_ = (AppDelegate*) ((NSApplication*)NSApp).delegate;
    return _;
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
    
    [self disableFeaturesByVersion];
    
    // update menu with current shortcuts layout
    ActionsShortcutsManager::Instance().SetMenuShortCuts([NSApp mainMenu]);
    
    if(configuration::is_sandboxed) {
        auto &sm = SandboxManager::Instance();
        if(sm.Empty()) {
            sm.AskAccessForPathSync(CommonPaths::Home(), false);
            if(m_MainWindows.empty())
                [self AllocateNewMainWindow];
        }
    }
}

- (void)disableFeaturesByVersion
{
    // disable some features available in menu by configuration limitation
    auto tag_from_lit   = [ ](const char *s) { return ActionsShortcutsManager::Instance().TagFromAction(s);       };
    auto menuitem       = [&](const char *s) { return [[NSApp mainMenu] itemWithTagHierarchical:tag_from_lit(s)]; };
    auto hide           = [&](const char *s) {
        auto item = menuitem(s);
        item.alternate = false;
        item.hidden = true;
    };
    
    if(!configuration::has_psfs)
        hide("menu.go.processes_list");
    if(!configuration::has_terminal) {
        hide("menu.view.show_terminal");
        hide("menu.view.panels_position.move_up");
        hide("menu.view.panels_position.move_down");
        hide("menu.view.panels_position.showpanels");
        hide("menu.view.panels_position.focusterminal");
        hide("menu.file.feed_filename_to_terminal");
        hide("menu.file.feed_filenames_to_terminal");        
    }
    
    if(!configuration::has_brief_system_overview)       hide("menu.command.system_overview");
    if(!configuration::has_unix_attributes_editing)     hide("menu.command.file_attributes");
    if(!configuration::has_detailed_volume_information) hide("menu.command.volume_information");
    if(!configuration::has_batch_rename)                hide("menu.command.batch_rename");
    // fix for a hanging separator in Lite version
    // BAD, BAD approach with hardcoded standalone tag!
    // need to write a mech to hide separators if surrounding menu items became hidden
    // or just w8 till all upgrade to 10.10, which does it automatically
    if(!configuration::has_brief_system_overview &&
       !configuration::has_unix_attributes_editing &&
       !configuration::has_detailed_volume_information)
        [[NSApp mainMenu] itemWithTagHierarchical:15021].hidden = true;
    if(!configuration::has_internal_viewer)             hide("menu.command.internal_viewer");
    if(!configuration::has_compression_operation)       hide("menu.command.compress");
    if(!configuration::has_fs_links_manipulation) {
        hide("menu.command.link_create_soft");
        hide("menu.command.link_create_hard");
        hide("menu.command.link_edit");
        [[NSApp mainMenu] itemContainingItemWithTagHierarchical:tag_from_lit("menu.command.link_edit")].hidden = true;
    }
    if(!configuration::has_network_connectivity) {
        hide("menu.go.connect.ftp");
        hide("menu.go.connect.sftp");
        hide("menu.go.quick_lists.connections");
        [[NSApp mainMenu] itemContainingItemWithTagHierarchical:tag_from_lit("menu.go.connect.ftp")].hidden = true;
    }
    
    menuitem("menu.file.calculate_checksum").hidden = !configuration::has_checksum_calculation;
    menuitem("menu.files.toggle_admin_mode").hidden = configuration::version != configuration::Version::Full ||
                                                      sysinfo::GetOSXVersion() < sysinfo::OSXVersion::OSX_10;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    if(!m_IsRunningTests && m_MainWindows.empty())
        [self AllocateNewMainWindow]; // if there's no restored windows - we'll create a freshly new one
    
    [NSApp setServicesProvider:self];
    NSUpdateDynamicServices();
    
    // init app dock progress bar
    m_DockTile = NSApplication.sharedApplication.dockTile;
    NSImageView *iv = [NSImageView new];
    iv.image = NSApplication.sharedApplication.applicationIconImage;
    m_DockTile.contentView = iv;
    m_ProgressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 2, m_DockTile.size.width, 18)];
    m_ProgressIndicator.style = NSProgressIndicatorBarStyle;
    m_ProgressIndicator.indeterminate = NO;
    m_ProgressIndicator.bezeled = true;
    m_ProgressIndicator.minValue = 0;
    m_ProgressIndicator.maxValue = 1;
    m_ProgressIndicator.hidden = true;
    [iv addSubview:m_ProgressIndicator];

    // calling modules running in background
    TemporaryNativeFileStorage::Instance(); // starting background purging implicitly

    if(configuration::is_for_app_store) // if we're building for AppStore - check if we want to ask user for rating
        AppStoreRatings::Instance().Go();
    
    [self checkIfNeedToShowNagScreen];
    
    if( configuration::version == configuration::Version::Full && !self.isRunningTests ) {
        g_Sparkle = [SUUpdater sharedUpdater];
        
        NSMenuItem *item = [[NSMenuItem alloc] init];
        item.title = NSLocalizedString(@"Check For Updates...", "Menu item title for check if any Files updates are here");
        item.target = g_Sparkle;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector"
        item.action = @selector(checkForUpdates:);
#pragma clang diagnostic pop
        [[[NSApp mainMenu] itemAtIndex:0].submenu insertItem:item atIndex:1];
    }
}

- (void) setupConfigDirectory
{
    auto fm = NSFileManager.defaultManager;
    NSString *config = [fm.applicationSupportDirectory stringByAppendingString:@"/Config/"];
    if( ![fm fileExistsAtPath:config] )
        [fm createDirectoryAtPath:config withIntermediateDirectories:true attributes:nil error:nil];
    m_ConfigDirectory = config.fileSystemRepresentationSafe;
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

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
    if(configuration::is_sandboxed &&
       [NSApp modalWindow] != nil)
        return; // we can show NSOpenPanel on startup. in this case applicationDidBecomeActive should be ignored
    
    if(m_MainWindows.empty())
    {
        if(!m_IsRunningTests)
            [self AllocateNewMainWindow];
    }
    else
    {
        // check that any window is visible, otherwise bring to front last window
        bool anyvisible = false;
        for(auto c: m_MainWindows)
            if(c.window.isVisible)
                anyvisible = true;
        
        if(!anyvisible)
        {
            NSArray *windows = NSApplication.sharedApplication.orderedWindows;
            [(NSWindow *)[windows objectAtIndex:0] makeKeyAndOrderFront:self];
        }     
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    if(m_IsRunningTests)
        return false;
    
    if(flag)
    {
        // check that any window is visible, otherwise bring to front last window
        bool anyvisible = false;
        for(auto c: m_MainWindows)
            if(c.window.isVisible)
                anyvisible = true;
        
        if(!anyvisible)
        {
            NSArray *windows = NSApplication.sharedApplication.orderedWindows;
            [(NSWindow *)[windows objectAtIndex:0] makeKeyAndOrderFront:self];
        }
        
        return NO;
    }
    else
    {
        if(m_MainWindows.empty())
            [self AllocateNewMainWindow];
        return YES;
    }

}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return NO;
}

- (MainWindowController*)AllocateNewMainWindow
{
    MainWindowController *mwc = [MainWindowController new];
    m_MainWindows.push_back(mwc);    
    [mwc showWindow:self];
    return mwc;
}

- (IBAction)NewWindow:(id)sender
{
    [self AllocateNewMainWindow];
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
        [alert addButtonWithTitle:NSLocalizedString(@"Stop And Quit", "Asking user for quitting app with activity - confirmation")];
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
    NSString *toAddress = @"feedback@filesmanager.info";
    NSString *subject = [NSString stringWithFormat: @"Feedback on %@ version %@ (%@)",
                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleName"],
                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"],
                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleVersion"]];
    NSString *bodyText = @"Write your message here.";
    NSString *mailtoAddress = [NSString stringWithFormat:@"mailto:%@?Subject=%@&body=%@", toAddress, subject, bodyText];
    NSString *urlstring = [mailtoAddress stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:urlstring]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Check if defaults changed.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (object == defaults) {
        // Check if the skin value was modified.
        if ([keyPath isEqualToString:@"Skin"]) {
            ApplicationSkin skin = (ApplicationSkin)[defaults integerForKey:@"Skin"];
            assert(skin == ApplicationSkin::Modern || skin == ApplicationSkin::Classic);
            
            [self willChangeValueForKey:@"skin"];
            m_Skin = skin;
            [self didChangeValueForKey:@"skin"];
        }
    }
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    [self  application:sender openFiles:@[filename]];;
    return true;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray<NSString *> *)filenames
{
    vector<string> paths;
    for( NSString *pathstring in filenames )
        if( auto fs = pathstring.fileSystemRepresentation )
            paths.emplace_back( fs );
    
    if( !paths.empty() )
        [self doRevealNativeItems:paths];
}

- (void) doRevealNativeItems:(const vector<string>&)_path
{
    // TODO: need to implement handling muliple directory paths in the future
    // grab first common directory and all corresponding items in it.
    string directory;
    vector<string> filenames;
    for( auto &i:_path ) {
        string parent = path(i).parent_path().native();

        if( directory.empty() )
            directory = parent;
        
        if( i != "/" )
            filenames.emplace_back( path(i).filename().native() );
    }

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
        if( NSString *urlstring = [item stringForType:@"public.file-url"] )
            if( NSURL *url = [NSURL URLWithString:urlstring] )
                if( NSString *unixpath = url.path )
                    if( auto fs = unixpath.fileSystemRepresentation  )
                        paths.emplace_back( fs );

    if( !paths.empty() )
        [self doRevealNativeItems:paths];
}

- (void)OnPreferencesCommand:(id)sender
{
    if(!m_PreferencesController)
    {
        NSMutableArray *controllers = [NSMutableArray new];
        [controllers addObject:[PreferencesWindowGeneralTab new]];
        [controllers addObject:[PreferencesWindowPanelsTab new]];
        if(configuration::has_internal_viewer)
            [controllers addObject:[PreferencesWindowViewerTab new]];
        [controllers addObject:[PreferencesWindowExternalEditorsTab new]];
        if(configuration::has_terminal)
            [controllers addObject:[PreferencesWindowTerminalTab new]];
        [controllers addObject:[PreferencesWindowHotkeysTab new]];
        m_PreferencesController = [[RHPreferencesWindowController alloc] initWithViewControllers:controllers
                                                                                        andTitle:@"Preferences"];
    }
    
    [m_PreferencesController showWindow:self];
}

- (IBAction)OnShowHelp:(id)sender
{
    NSString *path = [NSBundle.mainBundle pathForResource:@"Help" ofType:@"pdf"];
    [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:path]];
}

- (bool)askToResetDefaults
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Are you sure want to reset settings to defaults?", "Asking user for confirmation on erasing custom settings - message");
    alert.informativeText = NSLocalizedString(@"This will erase all your custom settings.", "Asking user for confirmation on erasing custom settings - informative text");
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    [[alert.buttons objectAtIndex:0] setKeyEquivalent:@""];
    if([alert runModal] == NSAlertFirstButtonReturn) {
        [NSUserDefaults.standardUserDefaults removePersistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
        [NSUserDefaults.standardUserDefaults synchronize];
        return  true;
    }
    return false;
}

- (void) checkIfNeedToShowNagScreen
{
    if(configuration::version != configuration::Version::Full)
        return;
    
    dispatch_to_background([=]{
        string app_name = "Files Pro.app";
        string app_id   = "info.filesmanager.Files-Pro";
        
        if(MASAppInstalledChecker::Instance().Has(app_name, app_id))
            return;
        
        // check cooldown criterias
        bool usage_time_exceeds_cooldown = false;
        NSString *def_start = @"CommonTrialFirstRunData";
        if(NSData *d = [NSUserDefaults.standardUserDefaults dataForKey:def_start]) {
            NSDate *first_run = objc_cast<NSDate>([NSUnarchiver unarchiveObjectWithData:d]);
            if( !first_run ) { // broken start date, fix and exit
                [NSUserDefaults.standardUserDefaults setObject:[NSArchiver archivedDataWithRootObject:NSDate.date] forKey:def_start];
                return;
            }
            seconds cooldown = 24h * 10; // 10 days cooldown
            NSDate *cooldown_ends = [first_run dateByAddingTimeInterval:cooldown.count()];
            if( [cooldown_ends compare:NSDate.date] == NSOrderedAscending )
                usage_time_exceeds_cooldown = true;
        }
        else
            [NSUserDefaults.standardUserDefaults setObject:[NSArchiver archivedDataWithRootObject:NSDate.date] forKey:def_start];
  
        bool starts_amount_exceeds_cooldown = false;
        NSString *def_runs  = @"CommonTrialFirstRunsTotal";
        long app_runs = [NSUserDefaults.standardUserDefaults integerForKey:def_runs];
        if(app_runs < 0)
            app_runs = 0;
        if(app_runs < 20) // 20 app starts cooldown
            [NSUserDefaults.standardUserDefaults setInteger:++app_runs forKey:def_runs];
        else
            starts_amount_exceeds_cooldown = true;

        // if we're still running a cooldown period - don't show a nag screen
        if(!usage_time_exceeds_cooldown && !starts_amount_exceeds_cooldown)
            return;
        
        // finally - show a nag screen
        dispatch_to_main_queue_after(500ms, [=]{
            TrialWindowController* twc = [[TrialWindowController alloc] init];
            [twc.window makeKeyAndOrderFront:self];
            [twc.window makeMainWindow];
        });
    });
}

- (IBAction)OnMenuToggleAdminMode:(id)sender
{
    if( RoutedIO::Instance().Enabled() )
        RoutedIO::Instance().TurnOff();
    else {
        bool result = RoutedIO::Instance().TurnOn();
        if( !result ) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = NSLocalizedString(@"Failed to access a privileged helper.", "Information that toggling admin mode on had failed");
            [alert addButtonWithTitle:NSLocalizedString(@"Ok", "")];
            [alert runModal];
        }
    }

    [self updateDockTileBadge];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    
    IF_MENU_TAG("menu.files.toggle_admin_mode") {
        bool enabled = RoutedIO::Instance().Enabled();
        item.title = enabled ?
            NSLocalizedString(@"Disable Admin Mode", "Menu item title for disabling an admin mode") :
            NSLocalizedString(@"Enable Admin Mode", "Menu item title for enabling an admin mode");
        return true;
    }
    
    return true;
}

@end
