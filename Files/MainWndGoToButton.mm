//
//  MainWndGoToButton.m
//  Directories
//
//  Created by Michael G. Kazakov on 11.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <unistd.h>
#import <sys/types.h>
#import <pwd.h>
#import <assert.h>
#import "MainWndGoToButton.h"
#import "AppDelegate.h"
#import "Common.h"
#import "MainWindowFilePanelState.h"
#import "MainWindowController.h"

static NSString *RealHomeDirectory()
{
    struct passwd *pw = getpwuid(getuid());
    assert(pw);
    return [NSString stringWithUTF8String:pw->pw_dir];
}

static size_t CommonCharsInPath(NSURL *_url, NSString *_path1)
{
    NSString *path2 = [_url path];
    
    bool b = [_path1 hasPrefix:path2];
    return b ? [path2 length] : 0;
}

struct AdditionalPath
{
    NSString *path;
    NSString *visible_path; // may be truncated in the middle for convenience
};

@implementation MainWndGoToButton
{
    NSMutableArray *m_UserDirs;
    NSArray *m_Volumes;        // array of NSUrl
    std::vector<AdditionalPath> m_OtherPanelsPaths;
    
    NSString *m_CurrentPath;

    __weak MainWindowFilePanelState *m_Owner;
}


- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {        
        [self awakeFromNib];
    }
    
    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) SetOwner:(MainWindowFilePanelState*) _owner
{
    m_Owner = _owner;
}

- (void)awakeFromNib
{
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(WillPopUp:)
     name:@"NSPopUpButtonWillPopUpNotification"
     object:nil];

    [self setBezelStyle:NSTexturedRoundedBezelStyle];
    [self setPullsDown:true];
    [self setRefusesFirstResponder:true];
    [self addItemWithTitle:@"Go to"];
    
    // grab user dir only in init, since they won't change
    m_UserDirs = [NSMutableArray arrayWithCapacity:16];
    
    { // home dir
        NSString *hd = RealHomeDirectory();
        NSURL *url = [NSURL fileURLWithPath:hd isDirectory:true];
        [m_UserDirs addObject:url];
    }

    { // desktop
        NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDesktopDirectory inDomains:NSUserDomainMask];
        assert([paths count] > 0);
        [m_UserDirs addObject:[paths objectAtIndex:0]];
    }
    
    { // documents
        NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        assert([paths count] > 0);
        [m_UserDirs addObject:[paths objectAtIndex:0]];
    }

    { // downloads
        NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDownloadsDirectory inDomains:NSUserDomainMask];
        assert([paths count] > 0);
        [m_UserDirs addObject:[paths objectAtIndex:0]];
    }

    { // movies
        NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSMoviesDirectory inDomains:NSUserDomainMask];
        assert([paths count] > 0);
        [m_UserDirs addObject:[paths objectAtIndex:0]];
    }

    { // music
        NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSMusicDirectory inDomains:NSUserDomainMask];
        assert([paths count] > 0);
        [m_UserDirs addObject:[paths objectAtIndex:0]];
    }

    { // pictures
        NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSPicturesDirectory inDomains:NSUserDomainMask];
        assert([paths count] > 0);
        [m_UserDirs addObject:[paths objectAtIndex:0]];
    }
}

- (void) UpdateUrls
{
    NSArray *keys = [NSArray arrayWithObjects:NSURLVolumeNameKey/*, NSURLPathKey*/, nil];
    m_Volumes = [[NSFileManager defaultManager]
                     mountedVolumeURLsIncludingResourceValuesForKeys:keys
                     options:NSVolumeEnumerationSkipHiddenVolumes];
}

- (void) UpdateOtherPanelPaths
{
    static NSDictionary* attributes = [NSDictionary dictionaryWithObject:[NSFont menuFontOfSize:0] forKey:NSFontAttributeName];
    m_OtherPanelsPaths.clear();
    
    bool append = [[NSUserDefaults standardUserDefaults] boolForKey:@"FilePanelsGeneralAppendOtherWindowsPathsToGoToMenu"];
    if(!append) return;
    
    std::vector<std::string> current_paths;
    [m_Owner GetFilePanelsGlobalPaths:current_paths];
    
    NSArray *main_wnd_controllers = [(AppDelegate*)[NSApp delegate] GetMainWindowControllers];
    for(MainWindowController *ctr in main_wnd_controllers)
    {
        MainWindowFilePanelState *state = [ctr FilePanelState];
        if(state == m_Owner)
            continue;
        
        std::vector<std::string> paths;
        [state GetFilePanelsGlobalPaths:paths];
    
        for(const auto& i: paths)
        {
            bool copy = false;
            for(const auto &j: current_paths)
                if(i == j)
                {
                    copy = true;
                    break;
                }
            if(copy) continue;
            
            NSString *path = [NSString stringWithUTF8String:i.c_str()];
            for(const auto &j: m_OtherPanelsPaths)
                if([j.path isEqualToString:path])
                {
                    copy = true;
                    break;
                }
            if(copy) continue;
            
            AdditionalPath ap;
            ap.path = path;
            ap.visible_path = StringByTruncatingToWidth(path, 600, kTruncateAtMiddle, attributes);
            m_OtherPanelsPaths.push_back(ap);
        }
    }
}

- (NSString*) GetCurrentSelectionPath
{
    NSInteger n = [self indexOfSelectedItem] - 1;
    
    if(n >= 0 && n < [m_UserDirs count])
    {
        NSURL *url = [m_UserDirs objectAtIndex:n];
        return [url path];
    }
    else if( n - [m_UserDirs count] - 1 < [m_Volumes count] )
    {
        NSURL *url = [m_Volumes objectAtIndex:n - [m_UserDirs count] - 1];
        return [url path];
    }
    else if( n - [m_UserDirs count] - [m_Volumes count] - 2 < m_OtherPanelsPaths.size())
    {
        return m_OtherPanelsPaths[n - [m_UserDirs count] - [m_Volumes count] - 2].path;
    }
    assert(0);

    return 0;
}

- (void) WillPopUp:(NSNotification *) notification
{
    [self UpdateUrls];
    [self UpdateOtherPanelPaths];
    
    [self removeAllItems];
    [self addItemWithTitle:@"Go to"];
    
    static const double icon_size = [NSFont systemFontSize];

    size_t common_path_max = 0;
    NSMenuItem *common_item = nil;

    for (NSURL *url in m_UserDirs)
    {
        NSError *error;
        NSString *name;
        [url getResourceValue:&name forKey:NSURLLocalizedNameKey error:&error];
        [self addItemWithTitle:name];
        
        NSImage *img;
        [url getResourceValue:&img forKey:NSURLEffectiveIconKey error:&error];
        if(img != nil)
        {
            [img setSize:NSMakeSize(icon_size, icon_size)];
            [[self lastItem] setImage:img];
        }
        
        if(m_CurrentPath != nil)
        {
            size_t n = CommonCharsInPath(url, m_CurrentPath);
            if(n > common_path_max)
            {
                common_path_max = n;
                common_item = [self itemWithTitle:name];
            }
        }        
    }

    [[self menu] addItem:[NSMenuItem separatorItem]];
    
    for (NSURL *url in m_Volumes)
    {
        NSError *error;
        NSString *volumeName;
        [url getResourceValue:&volumeName forKey:NSURLVolumeNameKey error:&error];
        [self addItemWithTitle:volumeName];
        
        NSImage *img;
        [url getResourceValue:&img forKey:NSURLEffectiveIconKey error:&error];
        if(img != nil)
        {
            [img setSize:NSMakeSize(icon_size, icon_size)];
            [[self lastItem] setImage:img];
        }
        
        if(m_CurrentPath != nil)
        {
            size_t n = CommonCharsInPath(url, m_CurrentPath);
            if(n > common_path_max)
            {
                common_path_max = n;
                common_item = [self itemWithTitle:volumeName];                
            }
        }
    }
    
    if(!m_OtherPanelsPaths.empty())
    {
        [[self menu] addItem:[NSMenuItem separatorItem]];
        for(const auto &i: m_OtherPanelsPaths)
            [self addItemWithTitle:i.visible_path];
    }
    
    if(common_item != nil)
        [common_item setState:NSOnState];
}

- (void) SetCurrentPath: (const char*)_path
{
    m_CurrentPath = [NSString stringWithUTF8String:_path];
}

@end
