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
    const std::string &AppBundle() noexcept;
    const std::string &Home() noexcept;
    const std::string &Documents() noexcept;
    const std::string &Desktop() noexcept;
    const std::string &Downloads() noexcept;
    const std::string &Applications() noexcept;
    const std::string &Utilities() noexcept;
    const std::string &Library() noexcept;
    const std::string &Pictures() noexcept;
    const std::string &Music() noexcept;
    const std::string &Movies() noexcept;
    const std::string &Root() noexcept;
    const std::string &AppTemporaryDirectory() noexcept;
    const std::string &StartupCWD() noexcept;
};
