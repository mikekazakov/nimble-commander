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

@implementation AppDelegate
{
    vector<MainWindowController *> m_MainWindows;
    RHPreferencesWindowController *m_PreferencesController;
    
    NSProgressIndicator *m_ProgressIndicator;
    NSDockTile          *m_DockTile;
    double              m_AppProgress;
    bool                m_IsRunningTests;
}

@synthesize isRunningTests = m_IsRunningTests;

- (id) init
{
    self = [super init];
    if(self) {
        m_IsRunningTests = (NSClassFromString(@"XCTestCase") != nil);
        m_AppProgress = -1;
        
        NSString *defaults_file = [NSBundle.mainBundle pathForResource:@"Defaults" ofType:@"plist"];
        NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaults_file];
        [NSUserDefaults.standardUserDefaults registerDefaults:defaults];
        [NSUserDefaults.standardUserDefaults addObserver:self
                                              forKeyPath:@"Skin"
                                                 options:NSKeyValueObservingOptionNew
                                                 context:NULL];
    }
    return self;
}

- (void)dealloc
{
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPath:@"Skin" context:NULL];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    // modules initialization
    NativeFSManager::Instance();
    
    ActionsShortcutsManager::Instance().DoInit();
    ActionsShortcutsManager::Instance().SetMenuShortCuts([NSApp mainMenu]);
    
    if(configuration::is_sandboxed) {
        auto &sm = SandboxManager::Instance();
        if(sm.Empty())
            sm.AskAccessForPath(CommonPaths::Get(CommonPaths::Home));
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
    TemporaryNativeFileStorage::StartBackgroundPurging();
    NewVersionChecker::Go();
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
    for(auto i = m_MainWindows.begin(); i < m_MainWindows.end(); ++i)
        if(*i == _wnd)
        {
            m_MainWindows.erase(i);
            break;
        }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    BOOL has_running_ops = NO;
    for (MainWindowController *wincont : m_MainWindows)
    {
        if (wincont.OperationsController.OperationsCount > 0)
        {
            has_running_ops = YES;
            break;
        }
        if(wincont.TerminalState && [wincont.TerminalState IsAnythingRunning])
        {
            has_running_ops = YES;
            break;
        }
    }
    
    if (has_running_ops)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"The application has running operations. Do you want to stop all operations and quit?"];
        [alert addButtonWithTitle:@"Stop And Quit"];
        [alert addButtonWithTitle:@"Cancel"];
        NSInteger result = [alert runModal];
        
        // If cancel is pressed.
        if (result == NSAlertSecondButtonReturn) return NSTerminateCancel;
        
        for (MainWindowController *wincont : m_MainWindows)
        {
            [wincont.OperationsController Stop];
            [wincont.TerminalState Terminate];
        }
    }
    
    return NSTerminateNow;
}

- (IBAction)OnMenuSendFeedback:(id)sender
{
    NSString *toAddress = @"feedback@filesmanager.info";
    NSString *subject = [NSString stringWithFormat: @"Feedback on Files version %@ (%@)",
                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleShortVersionString"],
                         [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleVersion"]];
    NSString *bodyText = @"Write your message here.";
    NSString *mailtoAddress = [NSString stringWithFormat:@"mailto:%@?Subject=%@&body=%@", toAddress, subject, bodyText];
    NSString *urlstring = [mailtoAddress stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:urlstring]];
}

- (ApplicationSkin)Skin
{
    ApplicationSkin skin = (ApplicationSkin)[NSUserDefaults.standardUserDefaults integerForKey:@"Skin"];
    assert(skin == ApplicationSkin::Modern || skin == ApplicationSkin::Classic);
    return skin;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Check if defaults changed.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (object == defaults)
    {
        // Check if the skin value was modified.
        if ([keyPath isEqualToString:@"Skin"])
        {
            ApplicationSkin skin = (ApplicationSkin)[defaults integerForKey:@"Skin"];
            assert(skin == ApplicationSkin::Modern || skin == ApplicationSkin::Classic);
            for (MainWindowController *wincont : m_MainWindows)
            {
                [wincont ApplySkin:skin];
            }
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
        [contr.FilePanelState RevealEntries:std::move(filenames) inPath:common_path];
    }
}

- (void)OnPreferencesCommand:(id)sender
{
    if(!m_PreferencesController)
    {
        auto controllers = @[[PreferencesWindowGeneralTab new],
                             [PreferencesWindowPanelsTab new],
                             [PreferencesWindowViewerTab new],
                             [PreferencesWindowExternalEditorsTab new],
                             [PreferencesWindowTerminalTab new],
                             [PreferencesWindowHotkeysTab new]
                             ];
        m_PreferencesController = [[RHPreferencesWindowController alloc] initWithViewControllers:controllers
                                                                                        andTitle:@"Preferences"];
    }
    
    [m_PreferencesController showWindow:self];
}

- (vector<MainWindowController*>) GetMainWindowControllers
{
    return m_MainWindows;
}

- (IBAction)OnShowHelp:(id)sender
{
    NSString *path = [NSBundle.mainBundle pathForResource:@"Help" ofType:@"pdf"];
    [NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:path]];
}

@end
