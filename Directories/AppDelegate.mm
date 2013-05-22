//
//  AppDelegate.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "AppDelegate.h"
#import "FontCache.h"
#import "MainWindowController.h"
#import "OperationProgressValueTransformer.h"
#import "OperationsController.h"
#import "Common.h"
#import <vector>
#import "FlexChainedStringsChunk.h"
#import "FSEventsDirUpdate.h"


@implementation AppDelegate
{
    std::vector<MainWindowController *> m_MainWindows;
}

+ (void)initialize
{
    InitGetTimeInNanoseconds();
    
    NSString *defaults_file = [[NSBundle mainBundle]
                               pathForResource:@"Defaults" ofType:@"plist"];
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaults_file];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void)dealloc
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObserver:self forKeyPath:@"Skin" context:NULL];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    // modules initialization
    FontCacheManager::Instance()->CreateFontCache((CFStringRef)@"Menlo Regular");
    FSEventsDirUpdate::RunDiskArbitration();

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults addObserver:self
               forKeyPath:@"Skin"
                  options:NSKeyValueObservingOptionNew
                  context:NULL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [NSValueTransformer setValueTransformer:[[OperationProgressValueTransformer alloc] init]
                                    forName:@"OperationProgressValueTransformer"];
    
    if(m_MainWindows.empty())
        [self AllocateNewMainWindow]; // if there's no restored windows - we'll create a freshly new one
    
    [NSApp setServicesProvider:self];
    NSUpdateDynamicServices();
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
    if(m_MainWindows.empty())
    {
        [self AllocateNewMainWindow];
    }
    else
    {
        // check that any window is visible, otherwise bring to front last window
        bool anyvisible = false;
        for(auto c: m_MainWindows)
            if([[c window] isVisible])
                anyvisible = true;
        
        if(!anyvisible)
        {
            NSArray *windows = [[NSApplication sharedApplication] orderedWindows];
            [(NSWindow *)[windows objectAtIndex:0] makeKeyAndOrderFront:self];
        }     
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    if(flag)
    {
        // check that any window is visible, otherwise bring to front last window
        bool anyvisible = false;
        for(auto c: m_MainWindows)
            if([[c window] isVisible])
                anyvisible = true;
        
        if(!anyvisible)
        {
            NSArray *windows = [[NSApplication sharedApplication] orderedWindows];
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

- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long) _ticket
{
    for(auto i: m_MainWindows)
        [i FireDirectoryChanged:_dir ticket:_ticket];
}

- (MainWindowController*)AllocateNewMainWindow
{
    MainWindowController *mwc = [[MainWindowController alloc] init];
    [mwc ApplySkin:self.Skin];
    mwc.window.restorable = YES;
    mwc.window.restorationClass = self.class;
    mwc.window.identifier = @"mainwindow";
    
    [mwc showWindow:self];
    m_MainWindows.push_back(mwc);
    return mwc;
}

- (IBAction)NewWindow:(id)sender
{
    [self AllocateNewMainWindow];
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    NSWindow *window = nil;
    if ([identifier isEqualToString:@"mainwindow"])
    {
        AppDelegate *app = [NSApp delegate];
        window = [[app AllocateNewMainWindow] window];
    }
    completionHandler(window, nil);
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
        }
    }
    
    return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    for(auto *i: m_MainWindows)
        [i SavePanelPaths];
}

- (IBAction)OnMenuSendFeedback:(id)sender
{
    NSString *toAddress = @"feedback@filesmanager.info";
    NSString *subject = [NSString stringWithFormat: @"Feedback on Files version %@ (%@)",
                         [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
                         [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
    NSString *bodyText = @"Write your message here.";
    NSString *mailtoAddress = [NSString stringWithFormat:@"mailto:%@?Subject=%@&body=%@", toAddress, subject, bodyText];
    NSString *urlstring = [mailtoAddress stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlstring]];
}

- (ApplicationSkin)Skin
{
    ApplicationSkin skin = (ApplicationSkin)[[NSUserDefaults standardUserDefaults] integerForKey:@"Skin"];
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

- (void)IClicked:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error
{
    // we support only one directory path now
    // TODO: need to implement handling muliple directory paths in the future
    char common_path[MAXPATHLEN];
    common_path[0]=0;
    FlexChainedStringsChunk *filenames = FlexChainedStringsChunk::Allocate();
    
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
            strcpy(path, [unixpath UTF8String]);
            
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
                        filenames->AddString(lastslash+1, nullptr);
                        
                }
                else if(strcmp(common_path, "/") == 0)
                { // add current item into root dir
                    if(*(lastslash+1) != 0)
                        filenames->AddString(lastslash+1, nullptr);
                }
            }
            else
            {// regular case
                *lastslash = 0;
                if(common_path[0]==0)
                { // get the first directory as main directory
                    strcpy(common_path, path);
                    filenames->AddString(lastslash+1, nullptr);
                }
                else if(strcmp(common_path, path) == 0)
                { // get only files which fall into common directory
                    filenames->AddString(lastslash+1, nullptr);
                }
            }
        }
    }
    
    // find window to ask
    NSArray *windows = [[NSApplication sharedApplication] orderedWindows];
    NSWindow *target_window = nil;
    for(NSWindow *wnd in windows)
        if(wnd != nil &&
           [wnd windowController] != nil &&
           [[wnd windowController] isKindOfClass:[MainWindowController class]])
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
        [contr RevealEntries:filenames inPath:common_path];
    }
}

@end
