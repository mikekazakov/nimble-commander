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
            static string path = getpwuid(getuid())->pw_dir;
            return path;
        }
        
        case Documents:
        {
            static string path = Get(CommonPaths::Home) + "/Documents";
            return path;
        }
            
        case Desktop:
        {
            static string path = Get(CommonPaths::Home) + "/Desktop";
            return path;
        }
        
        case Downloads:
        {
            static string path = Get(CommonPaths::Home) + "/Downloads";
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
            static string path = Get(CommonPaths::Home) + "/Library";
            return path;
        }
        
        case Movies:
        {
            static string path = Get(CommonPaths::Home) + "/Movies";
            return path;
        }
        
        case Music:
        {
            static string path = Get(CommonPaths::Home) + "/Music";
            return path;
        }
            
        case Pictures:
        {
            static string path = Get(CommonPaths::Home) + "/Pictures";
            return path;
        }
        
        default: assert(0);
    }
    static string dummy;
    return dummy;
}
