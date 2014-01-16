//
//  MainWndGoToButton.m
//  Directories
//
//  Created by Michael G. Kazakov on 11.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <assert.h>
#import "MainWndGoToButton.h"
#import "AppDelegate.h"
#import "Common.h"
#import "MainWindowFilePanelState.h"
#import "MainWindowController.h"
#import "common_paths.h"

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
	}
    
	CFRelease(sflRef);
    
    if([result count] > 0) return result;
    return 0;
}

static NSURL *URLFromCommonPath(CommonPaths::Path _p)
{
    NSString *str = [NSString stringWithUTF8String:CommonPaths::Get(_p).c_str()];
    return [NSURL fileURLWithPath:str isDirectory:true];
}

static NSMutableArray *GetHardcodedFavorites()
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:10];
    [result addObject:URLFromCommonPath(CommonPaths::Home)];
    [result addObject:URLFromCommonPath(CommonPaths::Desktop)];
    [result addObject:URLFromCommonPath(CommonPaths::Documents)];
    [result addObject:URLFromCommonPath(CommonPaths::Downloads)];
    [result addObject:URLFromCommonPath(CommonPaths::Movies)];
    [result addObject:URLFromCommonPath(CommonPaths::Music)];
    [result addObject:URLFromCommonPath(CommonPaths::Pictures)];
    return result;
}

static NSString *KeyEquivalentForUserDir(int _dir_ind)
{
    switch(_dir_ind) {
        case  0: return @"1";
        case  1: return @"2";
        case  2: return @"3";
        case  3: return @"4";
        case  4: return @"5";
        case  5: return @"6";
        case  6: return @"7";
        case  7: return @"8";
        case  8: return @"9";
        case  9: return @"0";
        case 10: return @"-";
        case 11: return @"=";
        default: return @"";
    }
}


@implementation MainWndGoToButton
{
    NSMutableArray  *m_UserDirs;       // array of NSUrls
    NSArray         *m_Volumes;        // array of NSUrls
    vector<AdditionalPath> m_OtherPanelsPaths;
    
    NSString *m_CurrentPath;

    __weak MainWindowFilePanelState *m_Owner;
}


- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(WillPopUp:)
                                                     name:@"NSPopUpButtonWillPopUpNotification"
                                                   object:self];
        
        [self setBezelStyle:NSTexturedRoundedBezelStyle];
        [self setPullsDown:true];
        [self setRefusesFirstResponder:true];
        [self addItemWithTitle:@"Go to"];
        
        // grab user dir only in init, since they won't change (we presume so - if not then user has to close/open Files window)
        m_UserDirs = GetFindersFavorites();
        if(m_UserDirs == NULL) // something bad happened, fallback to hardcoded version
            m_UserDirs = GetHardcodedFavorites(); // (not sure if this will be ever called)
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
    
    vector<string> current_paths;
    MainWindowFilePanelState *owner = m_Owner;
    [owner GetFilePanelsGlobalPaths:current_paths];
    
    auto main_wnd_controllers = [(AppDelegate*)[NSApplication sharedApplication].delegate GetMainWindowControllers];
    for(auto ctr: main_wnd_controllers)
    {
        MainWindowFilePanelState *state = [ctr FilePanelState];
        if(state == owner)
            continue;
        
        vector<string> paths;
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
        NSMenuItem *menuitem = [NSMenuItem new];
        [menuitem setTitle:name];
        [[self menu] addItem:menuitem];

        NSImage *img;
        [url getResourceValue:&img forKey:NSURLEffectiveIconKey error:&error];
        if(img != nil)
        {
            [img setSize:NSMakeSize(icon_size, icon_size)];
            [menuitem setImage:img];
        }
        
        if(m_CurrentPath != nil)
        {
            size_t n = CommonCharsInPath(url, m_CurrentPath);
            if(n > common_path_max)
            {
                common_path_max = n;
                common_item = menuitem;
            }
        }

        [menuitem setKeyEquivalent:KeyEquivalentForUserDir(userdir_ind)];
        [menuitem setKeyEquivalentModifierMask:0];
        ++userdir_ind;
    }

    [[self menu] addItem:[NSMenuItem separatorItem]];
    
    for (NSURL *url in m_Volumes)
    {
        NSError *error;
        NSString *volumeName;
        [url getResourceValue:&volumeName forKey:NSURLVolumeNameKey error:&error];
        NSMenuItem *menuitem = [NSMenuItem new];
        [menuitem setTitle:volumeName];
        [[self menu] addItem:menuitem];
        
        NSImage *img;
        [url getResourceValue:&img forKey:NSURLEffectiveIconKey error:&error];
        if(img != nil)
        {
            [img setSize:NSMakeSize(icon_size, icon_size)];
            [menuitem setImage:img];
        }
        
        if(m_CurrentPath != nil)
        {
            size_t n = CommonCharsInPath(url, m_CurrentPath);
            if(n > common_path_max)
            {
                common_path_max = n;
                common_item = menuitem;
            }
        }
    }
    
    if(!m_OtherPanelsPaths.empty())
    {
        [[self menu] addItem:[NSMenuItem separatorItem]];
        for(const auto &i: m_OtherPanelsPaths)
        {
            NSMenuItem *menuitem = [NSMenuItem new];
            [menuitem setTitle:i.visible_path];
            [[self menu] addItem:menuitem];
        }
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
