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

static NSMutableArray *GetFindersFavorites()
{
    // thanks Adam Strzelecki nanoant.com
    // https://gist.github.com/nanoant/1244807
    
    NSMutableArray *result = [NSMutableArray new];
    
    UInt32 seed;
    LSSharedFileListRef sflRef = LSSharedFileListCreate(NULL, kLSSharedFileListFavoriteItems, NULL);
    NSArray *list = (NSArray *)CFBridgingRelease(LSSharedFileListCopySnapshot(sflRef, &seed));
	LSSharedFileListItemRef sflItemBeforeRef = (LSSharedFileListItemRef)kLSSharedFileListItemBeforeFirst;
    
	for(NSObject *object in list) {
		LSSharedFileListItemRef sflItemRef = (__bridge LSSharedFileListItemRef)object;
		CFURLRef urlRef = NULL;
		LSSharedFileListItemResolve(sflItemRef,
                                    kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes,
                                    &urlRef,
                                    NULL);
        
        if(urlRef != 0) {
            NSURL* url = (__bridge NSURL*)urlRef;
            
            if([[url scheme] isEqualToString:@"file"] &&
               [[url resourceSpecifier] rangeOfString:@".cannedSearch/"].location == NSNotFound)
                [result addObject: url];
            CFRelease(urlRef);
        }
		sflItemBeforeRef = sflItemRef;
	}
    
	CFRelease(sflRef);
    
    if([result count] > 0) return result;
    return 0;
}

static NSMutableArray *GetHardcodedFavorites()
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:16];
    
    { // home dir
        NSString *hd = RealHomeDirectory();
        NSURL *url = [NSURL fileURLWithPath:hd isDirectory:true];
        [result addObject:url];
    }
    
    { // desktop
        NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDesktopDirectory inDomains:NSUserDomainMask];
        assert([paths count] > 0);
        [result addObject:[paths objectAtIndex:0]];
    }
    
    { // documents
        NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        assert([paths count] > 0);
        [result addObject:[paths objectAtIndex:0]];
    }
    
    { // downloads
        NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDownloadsDirectory inDomains:NSUserDomainMask];
        assert([paths count] > 0);
        [result addObject:[paths objectAtIndex:0]];
    }
    
    { // movies
        NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSMoviesDirectory inDomains:NSUserDomainMask];
        assert([paths count] > 0);
        [result addObject:[paths objectAtIndex:0]];
    }
    
    { // music
        NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSMusicDirectory inDomains:NSUserDomainMask];
        assert([paths count] > 0);
        [result addObject:[paths objectAtIndex:0]];
    }
    
    { // pictures
        NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSPicturesDirectory inDomains:NSUserDomainMask];
        assert([paths count] > 0);
        [result addObject:[paths objectAtIndex:0]];
    }
    
    return result;
}

@implementation MainWndGoToButton
{
    NSMutableArray  *m_UserDirs;       // array of NSUrls
    NSArray         *m_Volumes;        // array of NSUrls
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
     object:self];

    [self setBezelStyle:NSTexturedRoundedBezelStyle];
    [self setPullsDown:true];
    [self setRefusesFirstResponder:true];
    [self addItemWithTitle:@"Go to"];
    
    // grab user dir only in init, since they won't change
    m_UserDirs = GetFindersFavorites();
    if(m_UserDirs == NULL) // something bad happened, fallback to hardcoded version
        m_UserDirs = GetHardcodedFavorites();
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

    int userdir_ind = 0;
    for (NSURL *url in m_UserDirs)
    {
        NSError *error;
        NSString *name;
        [url getResourceValue:&name forKey:NSURLLocalizedNameKey error:&error];
        [self addItemWithTitle:name];
        
        NSMenuItem *last = [self lastItem];
        
        NSImage *img;
        [url getResourceValue:&img forKey:NSURLEffectiveIconKey error:&error];
        if(img != nil)
        {
            [img setSize:NSMakeSize(icon_size, icon_size)];
            [last setImage:img];
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

        if(userdir_ind <= 11) {
            switch(userdir_ind) { // BAD, UGLY CODE!
                case  0: [last setKeyEquivalent:@"1"]; break;
                case  1: [last setKeyEquivalent:@"2"]; break;
                case  2: [last setKeyEquivalent:@"3"]; break;
                case  3: [last setKeyEquivalent:@"4"]; break;
                case  4: [last setKeyEquivalent:@"5"]; break;
                case  5: [last setKeyEquivalent:@"6"]; break;
                case  6: [last setKeyEquivalent:@"7"]; break;
                case  7: [last setKeyEquivalent:@"8"]; break;
                case  8: [last setKeyEquivalent:@"9"]; break;
                case  9: [last setKeyEquivalent:@"0"]; break;
                case 10: [last setKeyEquivalent:@"-"]; break;
                case 11: [last setKeyEquivalent:@"="]; break;
            }
            [[self lastItem] setKeyEquivalentModifierMask:0];
        }
        ++userdir_ind;
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
    
    [[self menu] setDelegate:self];
}

- (void) SetCurrentPath: (const char*)_path
{
    m_CurrentPath = [NSString stringWithUTF8String:_path];
}

- (void)menuDidClose:(NSMenu *)menu
{
    for(NSMenuItem* i in [[self menu] itemArray])
        [i setKeyEquivalent:@""];
}

@end
