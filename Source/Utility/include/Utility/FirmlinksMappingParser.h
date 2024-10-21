// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <string_view>
#include <vector>

namespace nc::utility {

class FirmlinksMappingParser
{
public:
    struct Firmlink {
        std::string target; // i.e. '/Applications'
        std::string source; // i.e. 'Applications'
        friend bool operator==(const Firmlink &_1st, const Firmlink &_2nd) noexcept;
        friend bool operator!=(const Firmlink &_1st, const Firmlink &_2nd) noexcept;
    };

    static std::vector<Firmlink> Parse(std::string_view _mapping);
};

} // namespace nc::utility
