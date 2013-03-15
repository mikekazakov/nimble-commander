//
//  MainWndGoToButton.m
//  Directories
//
//  Created by Michael G. Kazakov on 11.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWndGoToButton.h"
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#include <assert.h>

static NSString *RealHomeDirectory()
{
    struct passwd *pw = getpwuid(getuid());
    assert(pw);
    return [NSString stringWithUTF8String:pw->pw_dir];
}


@implementation MainWndGoToButton
{
    NSMutableArray *m_UserDirs;
    NSArray *m_Volumes;
}


- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
    }
    
    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib
{
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(WillPopUp:)
     name:@"NSPopUpButtonWillPopUpNotification"
     object:nil];
    
    [self setPullsDown:true];
    [self setTitle:@"Go to"];
    
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
    
    
    
//    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES );
//    NSArray* paths = [[NSFileManager defaultManager]
//                      URLsForDirectory:NSUserDirectory
//                      inDomains:NSUserDomainMask];

    

    
    
}

- (void) UpdateUrls
{
    NSArray *keys = [NSArray arrayWithObjects:NSURLVolumeNameKey, NSURLPathKey, nil];
    m_Volumes = [[NSFileManager defaultManager]
                     mountedVolumeURLsIncludingResourceValuesForKeys:keys
                     options:NSVolumeEnumerationSkipHiddenVolumes];
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
    assert(0);

    return 0;
}

- (void) WillPopUp:(NSNotification *) notification
{
    [self UpdateUrls];
    
    [self removeAllItems];
    [self addItemWithTitle:@"Go to"];

    for (NSURL *url in m_UserDirs)
    {
        NSError *error;
        NSString *name;
        [url getResourceValue:&name forKey:NSURLLocalizedNameKey error:&error];
        [self addItemWithTitle:name];
    }

    [[self menu] addItem:[NSMenuItem separatorItem]];
    
    for (NSURL *url in m_Volumes)
    {
        NSError *error;
        NSString *volumeName;
//        NSString *pathName;
        [url getResourceValue:&volumeName forKey:NSURLVolumeNameKey error:&error];
//        pathName = [url path];
        [self addItemWithTitle:volumeName];
    }
    
//    [self addItemWithTitle:@"Abra1!"];
//    [self addItemWithTitle:@"Abra2!"];
    
//    [self selectItemAtIndex:1];
}

@end
