//
//  common_paths.mm
//  Files
//
//  Created by Michael G. Kazakov on 24.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <pwd.h>
#import "common_paths.h"

const string &CommonPaths::Get(CommonPaths::Path _path)
{
    switch (_path) {
        case Home:
        {
            static dispatch_once_t onceToken;
            static string path;
            dispatch_once(&onceToken, ^{
                path = getpwuid(getuid())->pw_dir;
            });
            return path;
        }
        
        case Documents:
        {
            static dispatch_once_t onceToken;
            static string path;
            dispatch_once(&onceToken, ^{
                NSArray* paths = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
                path = [[[paths objectAtIndex:0] path] fileSystemRepresentation];
            });
            return path;
        }
            
        case Desktop:
        {
            static dispatch_once_t onceToken;
            static string path;
            dispatch_once(&onceToken, ^{
                NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDesktopDirectory inDomains:NSUserDomainMask];
                path = [[[paths objectAtIndex:0] path] fileSystemRepresentation];
            });

            return path;
        }
        
        case Downloads:
        {
            static dispatch_once_t onceToken;
            static string path;
            dispatch_once(&onceToken, ^{
                NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSDownloadsDirectory inDomains:NSUserDomainMask];
                path = [[[paths objectAtIndex:0] path] fileSystemRepresentation];
            });
            return path;
        }
            
        case Applications:
        {
            static string path = "/Applications/";
            return path;
        }
         
        case Utilities:
        {
            static string path = "/Applications/Utilities/";
            return path;
        }
            
        case Library:
        {
            static dispatch_once_t onceToken;
            static string path;
            dispatch_once(&onceToken, ^{
            NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask];
                path = [[[paths objectAtIndex:0] path] fileSystemRepresentation];
            });
            return path;
        }
        
        case Movies:
        {
            static dispatch_once_t onceToken;
            static string path;
            dispatch_once(&onceToken, ^{
                NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSMoviesDirectory inDomains:NSUserDomainMask];
                path = [[[paths objectAtIndex:0] path] fileSystemRepresentation];
            });
            return path;
        }
        
        case Music:
        {
            static dispatch_once_t onceToken;
            static string path;
            dispatch_once(&onceToken, ^{
                NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSMusicDirectory inDomains:NSUserDomainMask];
                path = [[[paths objectAtIndex:0] path] fileSystemRepresentation];
            });
            return path;
        }
            
        case Pictures:
        {
            static dispatch_once_t onceToken;
            static string path;
            dispatch_once(&onceToken, ^{
                NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSPicturesDirectory inDomains:NSUserDomainMask];
                path = [[[paths objectAtIndex:0] path] fileSystemRepresentation];
            });
            return path;
        }
        
        default: assert(0);
    }
    static string dummy;
    return dummy;
}
