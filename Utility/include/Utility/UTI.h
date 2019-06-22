// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>

namespace nc::utility {

class UTIDB
{
public:
    virtual ~UTIDB() = 0;    
    
    virtual std::string UTIForExtension(const std::string &_extension) const = 0;
    
    virtual bool IsDeclaredUTI(const std::string &_uti) const = 0;
    
    virtual bool IsDynamicUTI(const std::string &_uti) const = 0;
};

}

