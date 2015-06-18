//
//  common_paths.mm
//  Files
//
//  Created by Michael G. Kazakov on 24.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <pwd.h>
#import "common_paths.h"

static string GetMainBundlePath()
{
    CFURLRef url = CFBundleCopyBundleURL(CFBundleGetMainBundle());
    char path[MAXPATHLEN];
    bool result = CFURLGetFileSystemRepresentation(url, true, (UInt8*)path, MAXPATHLEN);
    CFRelease(url);
    return result ? string(path) : string("");
}

static string ensure_tr_slash( string _str )
{
    if(_str.empty() || _str.back() != '/')
        _str += '/';
    return _str;
}

const string &CommonPaths::Get(CommonPaths::Path _path)
{
    switch (_path) {
        case Home:
        {
            static auto path = ensure_tr_slash(getpwuid(getuid())->pw_dir);
            return path;
        }
        
        case Documents:
        {
            static auto path = Get(CommonPaths::Home) + "Documents/";
            return path;
        }
            
        case Desktop:
        {
            static auto path = Get(CommonPaths::Home) + "Desktop/";
            return path;
        }
        
        case Downloads:
        {
            static auto path = Get(CommonPaths::Home) + "Downloads/";
            return path;
        }
            
        case Applications:
        {
            static auto path = "/Applications/"s;
            return path;
        }
         
        case Utilities:
        {
            static auto path = "/Applications/Utilities/"s;
            return path;
        }
            
        case Library:
        {
            static auto path = Get(CommonPaths::Home) + "Library/";
            return path;
        }
        
        case Movies:
        {
            static auto path = Get(CommonPaths::Home) + "Movies/";
            return path;
        }
        
        case Music:
        {
            static auto path = Get(CommonPaths::Home) + "Music/";
            return path;
        }
            
        case Pictures:
        {
            static auto path = Get(CommonPaths::Home) + "Pictures/";
            return path;
        }
        
        case AppBundle:
        {
            static auto path = ensure_tr_slash(GetMainBundlePath());
            return path;
        }
            
        case Root:
        {
            static auto path = "/"s;
            return path;
        }
        
        default: assert(0);
    }
    static auto dummy = ""s;
    return dummy;
}
