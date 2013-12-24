//
//  common_paths.h
//  Files
//
//  Created by Michael G. Kazakov on 24.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <string>

using namespace std;

struct CommonPaths
{
    enum Path {
        Home,
        Documents,
        Desktop,
        Downloads,
        Applications,
        Utilities,
        Library,
        Pictures,
        Music,
        Movies
    };
    
    // returned paths may contain or not contain trailing slash
    static string Get(Path _path);
};
