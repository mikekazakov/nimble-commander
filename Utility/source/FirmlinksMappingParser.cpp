// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FirmlinksMappingParser.h>
#include <boost/algorithm/string/split.hpp>

namespace nc::utility {

std::vector<FirmlinksMappingParser::Firmlink>
FirmlinksMappingParser::Parse( std::string_view _mapping )
{
    std::vector<std::string> by_line;
    boost::algorithm::split(by_line, _mapping, [](auto c){ return c == '\x0A'; } );
    
    std::vector<Firmlink> result;    
    
    for( const auto &line: by_line ) {
        std::vector<std::string> by_part;
        boost::algorithm::split(by_part, line, [](auto c){ return c == '\x09'; } );
        if( by_part.size() == 2 ) {
            result.push_back({by_part[0], by_part[1]});
        }
    }
    return result;
}

bool operator==(const FirmlinksMappingParser::Firmlink &_1st,
                const FirmlinksMappingParser::Firmlink &_2nd) noexcept
{
    return _1st.target == _2nd.target && _1st.source == _2nd.source;
}

bool operator!=(const FirmlinksMappingParser::Firmlink &_1st,
                const FirmlinksMappingParser::Firmlink &_2nd) noexcept
{
    return !(_1st == _2nd);
}

}

