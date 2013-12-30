//
//  common_paths.mm
//  Files
//
//  Created by Michael G. Kazakov on 24.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <pwd.h>
#import "common_paths.h"

string CommonPaths::Get(CommonPaths::Path _path)
{
    switch (_path) {
        case Home:
            return getpwuid(getuid())->pw_dir;
        
        case Documents:
        {
            NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
            return [[[paths objectAtIndex:0] path] fileSystemRepresentation];
        }
            
        case Desktop:
        {
            NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDesktopDirectory inDomains:NSUserDomainMask];
            return [[[paths objectAtIndex:0] path] fileSystemRepresentation];
        }
            
        case Downloads:
        {
            NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDownloadsDirectory inDomains:NSUserDomainMask];
            return [[[paths objectAtIndex:0] path] fileSystemRepresentation];
        }
            
        case Applications:
            return "/Applications/";
         
        case Utilities:
            return "/Applications/Utilities/";
            
        case Library:
        {
            NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
            return [[[paths objectAtIndex:0] path] fileSystemRepresentation];
        }
        
        case Movies:
        {
            NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSMoviesDirectory inDomains:NSUserDomainMask];
            return [[[paths objectAtIndex:0] path] fileSystemRepresentation];
        }
        
        case Music:
        {
            NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSMusicDirectory inDomains:NSUserDomainMask];
            return [[[paths objectAtIndex:0] path] fileSystemRepresentation];
        }
            
        case Pictures:
        {
            NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSPicturesDirectory inDomains:NSUserDomainMask];
            return [[[paths objectAtIndex:0] path] fileSystemRepresentation];
        }
    }
    return "";
}
