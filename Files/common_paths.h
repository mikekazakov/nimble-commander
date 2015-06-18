//
//  common_paths.h
//  Files
//
//  Created by Michael G. Kazakov on 24.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

struct CommonPaths
{
    enum Path {
        AppBundle,
        Home,
        Documents,
        Desktop,
        Downloads,
        Applications,
        Utilities,
        Library,
        Pictures,
        Music,
        Movies,
        Root
    };
    
    // returned paths will contain a trailing slash
    static const string &Get(Path _path);
};
