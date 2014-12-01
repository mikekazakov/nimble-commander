//
//  AppDelegate.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "AppDelegate.h"
#import "MainWindowController.h"
#import "OperationsController.h"
#import "Common.h"
#import "chained_strings.h"
#import "3rd_party/RHPreferences/RHPreferences/RHPreferences.h"
#import "PreferencesWindowGeneralTab.h"
#import "PreferencesWindowPanelsTab.h"
#import "PreferencesWindowViewerTab.h"
#import "PreferencesWindowExternalEditorsTab.h"
#import "PreferencesWindowTerminalTab.h"
#import "PreferencesWindowHotkeysTab.h"
#import "TemporaryNativeFileStorage.h"
#import "NewVersionChecker.h"
#import "MainWindowTerminalState.h"
#import "NativeFSManager.h"
#import "ActionsShortcutsManager.h"
#import "MainWindowFilePanelState.h"
#import "SandboxManager.h"
#import "common_paths.h"
#import "MASAppInstalledChecker.h"
#import "TrialWindowController.h"
#import "RoutedIO.h"

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
}

@synthesize isRunningTests = m_IsRunningTests;
@synthesize startupCWD = m_StartupCWD;
@synthesize skin = m_Skin;
@synthesize mainWindowControllers = m_MainWindows;

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
    NativeFSManager::Instance();
        
    // disable some features available in menu by configuration limitation
    auto tag_from_lit   = [=](const char *s){ return ActionsShortcutsManager::Instance().TagFromAction(s);       };
    auto menuitem       = [=](const char *s){ return [[NSApp mainMenu] itemWithTagHierarchical:tag_from_lit(s)]; };
    if(!configuration::has_psfs)
        menuitem("menu.go.processes_list").hidden = true;
    if(!configuration::has_terminal)
        menuitem("menu.view.show_terminal").hidden = true;
    if(!configuration::has_brief_system_overview)
        menuitem("menu.command.system_overview").hidden = true;
    if(!configuration::has_unix_attributes_editing)
        menuitem("menu.command.file_attributes").hidden = true;
    if(!configuration::has_detailed_volume_information)
        menuitem("menu.command.volume_information").hidden = true;
    // fix for a hanging separator in Lite version
    // BAD, BAD approach with hardcoded standalone tag!
    // need to write a mech to hide separators if surrounding menu items became hidden
    // or just w8 till all upgrade to 10.10, which does it automatically
    if(!configuration::has_brief_system_overview &&
       !configuration::has_unix_attributes_editing &&
       !configuration::has_detailed_volume_information)
        [[NSApp mainMenu] itemWithTagHierarchical:15021].hidden = true;
    if(!configuration::has_internal_viewer)
        menuitem("menu.command.internal_viewer").hidden = true;
    if(!configuration::has_compression_operation)
        menuitem("menu.command.compress").hidden = true;
    if(!configuration::has_fs_links_manipulation) {
        menuitem("menu.command.link_create_soft").hidden = true;
        menuitem("menu.command.link_create_hard").hidden = true;
        menuitem("menu.command.link_edit").hidden = true;
        [[NSApp mainMenu] itemContainingItemWithTagHierarchical:tag_from_lit("menu.command.link_edit")].hidden = true;
    }
    if(!configuration::has_network_connectivity) {
        menuitem("menu.go.connect.ftp").hidden = true;
        menuitem("menu.go.connect.sftp").hidden = true;        
        [[NSApp mainMenu] itemContainingItemWithTagHierarchical:tag_from_lit("menu.go.connect.ftp")].hidden = true;
    }
    
    menuitem("menu.file.calculate_checksum").hidden = !configuration::has_checksum_calculation;
    menuitem("menu.files.try_full_version").hidden = configuration::version == configuration::Version::Full;
    menuitem("menu.files.toggle_admin_mode").hidden = configuration::version != configuration::Version::Full;
    
    // update menu with current shortcuts layout
    ActionsShortcutsManager::Instance().SetMenuShortCuts([NSApp mainMenu]);
    
    
    if(configuration::is_sandboxed) {
        auto &sm = SandboxManager::Instance();
        if(sm.Empty()) {
            sm.AskAccessForPathSync(CommonPaths::Get(CommonPaths::Home), false);
            if(m_MainWindows.empty())
                [self AllocateNewMainWindow];
        }
    }
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

    if(!configuration::is_sandboxed)
        NewVersionChecker::Go(); // we check for new versions only for non-sanboxed (say non-MAS) version
    
    [self checkIfNeedToShowNagScreen];
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
        [alert setMessageText:@"The application has running operations. Do you want to stop all operations and quit?"];
        [alert addButtonWithTitle:@"Stop And Quit"];
        [alert addButtonWithTitle:@"Cancel"];
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

- (void)IClicked:(NSPasteboard *)pboard userData:(NSString *)data error:(__strong NSString **)error
{
    // we support only one directory path now
    // TODO: need to implement handling muliple directory paths in the future
    char common_path[MAXPATHLEN];
    common_path[0]=0;
    chained_strings filenames;
    
    // compose requested path and items names
    NSArray *items = [pboard pasteboardItems];
    for( NSPasteboardItem *item in items )
    {
        NSString *urlstring = [item stringForType:@"public.file-url"];
        if (urlstring != nil)
        {
            NSURL *url = [NSURL URLWithString:urlstring];
            NSString *unixpath = [url path];
            
            char path[MAXPATHLEN];
            strcpy(path, [unixpath fileSystemRepresentation]);
            
            // get directory path
            char *lastslash = strrchr(path, '/');
            if(!lastslash)
                continue; // malformed ?
            if(lastslash == path)
            {// input is inside a root dir or is a root dir itself
                if(common_path[0]==0)
                { // set common directory as root
                    strcpy(common_path, "/");
                    if(*(lastslash+1) != 0)
                        filenames.push_back(lastslash+1, nullptr);
                        
                }
                else if(strcmp(common_path, "/") == 0)
                { // add current item into root dir
                    if(*(lastslash+1) != 0)
                        filenames.push_back(lastslash+1, nullptr);
                }
            }
            else
            {// regular case
                *lastslash = 0;
                if(common_path[0]==0)
                { // get the first directory as main directory
                    strcpy(common_path, path);
                    filenames.push_back(lastslash+1, nullptr);
                }
                else if(strcmp(common_path, path) == 0)
                { // get only files which fall into common directory
                    filenames.push_back(lastslash+1, nullptr);
                }
            }
        }
    }
    
    // find window to ask
    NSWindow *target_window = nil;
    for(NSWindow *wnd in NSApplication.sharedApplication.orderedWindows)
        if(wnd != nil &&
           wnd.windowController != nil &&
           [wnd.windowController isKindOfClass:[MainWindowController class]])
        {
            target_window = wnd;
            break;
        }
    
    if(!target_window)
    {
        [self AllocateNewMainWindow];
        target_window = [m_MainWindows.back() window];
    }

    if(target_window)
    {
        [target_window makeKeyAndOrderFront:self];
        MainWindowController *contr = (MainWindowController*)[target_window windowController];
        [contr.filePanelsState RevealEntries:std::move(filenames) inPath:common_path];
    }
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
    alert.messageText = @"Are you sure want to reset settings to defaults?";
    alert.informativeText = @"This will erase all your custom settings.";
    [alert addButtonWithTitle:@"Ok"];
    [alert addButtonWithTitle:@"Cancel"];
    [[alert.buttons objectAtIndex:0] setKeyEquivalent:@""];
    if([alert runModal] == NSAlertFirstButtonReturn) {
        [NSUserDefaults.standardUserDefaults removePersistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
        [NSUserDefaults.standardUserDefaults synchronize];
        return  true;
    }
    return false;
}

- (IBAction)OnMenuTryFullVersion:(id)sender
{
    NSString *url_string = @"http://filesmanager.info/downloads/latest.dmg";
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:url_string]];
}

- (void) checkIfNeedToShowNagScreen
{
    if(configuration::version != configuration::Version::Full)
        return;
    
    dispatch_to_background(^{
        string app_name = "Files Pro.app";
        string app_id   = "info.filesmanager.Files-Pro";
        
        if(MASAppInstalledChecker::Instance().Has(app_name, app_id))
            return;
        
        // check cooldown criterias
        bool usage_time_exceeds_cooldown = false;
        NSString *def_start = @"CommonTrialFirstRunData";
        if(NSData *d = [NSUserDefaults.standardUserDefaults dataForKey:def_start]) {
            NSDate *first_run = (NSDate*)[NSUnarchiver unarchiveObjectWithData:d];
            if(![first_run isKindOfClass:NSDate.class]) { // broken start date, fix and exit
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
        dispatch_to_main_queue_after(500ms, ^{
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
    else
        RoutedIO::Instance().TurnOn();
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    
    IF_MENU_TAG("menu.files.toggle_admin_mode") {
        bool enabled = RoutedIO::Instance().Enabled();
        item.title = enabled ? @"Disable Admin Mode" : @"Enable Admin Mode";
        return true;
    }
    
    return true;
}

@end
