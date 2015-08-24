//
//  common_paths.mm
//  Files
//
//  Created by Michael G. Kazakov on 24.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <CoreFoundation/CoreFoundation.h>
#import <sys/param.h>
#import <pwd.h>
#import <unistd.h>
#import "CommonPaths.h"

namespace CommonPaths
{

static std::string GetMainBundlePath()
{
    CFURLRef url = CFBundleCopyBundleURL(CFBundleGetMainBundle());
    char path[MAXPATHLEN];
    bool result = CFURLGetFileSystemRepresentation(url, true, (UInt8*)path, MAXPATHLEN);
    CFRelease(url);
    return result ? std::string(path) : std::string("");
}

static std::string ensure_tr_slash( std::string _str )
{
    if(_str.empty() || _str.back() != '/')
        _str += '/';
    return _str;
}

const std::string &AppBundle()
{
    static auto path = ensure_tr_slash(GetMainBundlePath());
    return path;
}

const std::string &Home()
{
    static auto path = ensure_tr_slash(getpwuid(getuid())->pw_dir);
    return path;
}

const std::string &Documents()
{
    static auto path = Home() + "Documents/";
    return path;
}

const std::string &Desktop()
{
    static auto path = Home() + "Desktop/";
    return path;
}

const std::string &Downloads()
{
    static auto path = Home() + "Downloads/";
    return path;
}

const std::string &Applications()
{
    static auto path = std::string("/Applications/");
    return path;
}

const std::string &Utilities()
{
    static auto path = std::string("/Applications/Utilities/");
    return path;
}

const std::string &Library()
{
    static auto path = Home() + "Library/";
    return path;
}

const std::string &Pictures()
{
    static auto path = Home() + "Pictures/";
    return path;
}

const std::string &Music()
{
    static auto path = Home() + "Music/";
    return path;
}

const std::string &Movies()
{
    static auto path = Home() + "Movies/";
    return path;
}

const std::string &Root()
{
    static auto path = std::string("/");
    return path;
}
    
}
