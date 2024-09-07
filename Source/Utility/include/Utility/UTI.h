// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <string_view>

namespace nc::utility {

class UTIDB
{
public:
    virtual ~UTIDB() = 0;

    virtual std::string UTIForExtension(std::string_view _extension) const = 0;

    virtual bool IsDeclaredUTI(std::string_view _uti) const = 0;

    virtual bool IsDynamicUTI(std::string_view _uti) const = 0;

    virtual bool ConformsTo(std::string_view _uti, std::string_view _conforms_to) const = 0;
};

} // namespace nc::utility
