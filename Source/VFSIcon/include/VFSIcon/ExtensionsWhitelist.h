// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>

namespace nc::vfsicon {

class ExtensionsWhitelist
{
public:
    virtual ~ExtensionsWhitelist() = 0;
    virtual bool AllowExtension( const std::string &_extension ) const = 0;
};

}
