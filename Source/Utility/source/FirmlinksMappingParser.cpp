// Copyright (C) 2019-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FirmlinksMappingParser.h>
#include <Base/algo.h>

namespace nc::utility {

std::vector<FirmlinksMappingParser::Firmlink> FirmlinksMappingParser::Parse(std::string_view _mapping)
{
    const std::vector<std::string> by_line = base::SplitByDelimiter(_mapping, '\x0A');

    std::vector<Firmlink> result;

    for( const auto &line : by_line ) {
        std::vector<std::string> by_part = base::SplitByDelimiter(line, '\x09');
        if( by_part.size() == 2 ) {
            result.push_back({by_part[0], by_part[1]});
        }
    }
    return result;
}

bool operator==(const FirmlinksMappingParser::Firmlink &_1st, const FirmlinksMappingParser::Firmlink &_2nd) noexcept
{
    return _1st.target == _2nd.target && _1st.source == _2nd.source;
}

bool operator!=(const FirmlinksMappingParser::Firmlink &_1st, const FirmlinksMappingParser::Firmlink &_2nd) noexcept
{
    return !(_1st == _2nd);
}

} // namespace nc::utility
