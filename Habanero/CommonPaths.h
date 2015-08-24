//
//  common_paths.h
//  Files
//
//  Created by Michael G. Kazakov on 24.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <string>

namespace CommonPaths
{    
    // returned paths will contain a trailing slash
    const std::string &AppBundle();
    const std::string &Home();
    const std::string &Documents();
    const std::string &Desktop();
    const std::string &Downloads();
    const std::string &Applications();
    const std::string &Utilities();
    const std::string &Library();
    const std::string &Pictures();
    const std::string &Music();
    const std::string &Movies();
    const std::string &Root();
};
