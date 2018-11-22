// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PathRoutines.h"
#include "Internal.h"
#include <Foundation/Foundation.h>
#include <Utility/StringExtras.h>

namespace nc::vfs::webdav {

std::pair<std::string, std::string> DeconstructPath(const std::string &_path)
{
    if( _path.empty() )
        return {};
    if( _path == "/" )
        return {"/", ".."};
    
    if( _path.back() == '/' ) {
        const auto ls = _path.find_last_of('/', _path.length() - 2);
        if( ls == std::string::npos )
            return {};
        return { _path.substr(0, ls+1), _path.substr(ls+1, _path.length() - ls - 2) };
    }
    else {
        const auto ls = _path.find_last_of('/');
        if( ls == std::string::npos )
            return {};
        return { _path.substr(0, ls+1), _path.substr(ls+1) };
    }
}

std::string URIEscape( const std::string &_unescaped )
{
    static const auto acs = NSCharacterSet.URLPathAllowedCharacterSet;
    if( auto str = [NSString stringWithUTF8StdString:_unescaped] )
        if( auto percents = [str stringByAddingPercentEncodingWithAllowedCharacters:acs] )
            if( auto utf8 = percents.UTF8String )
                return utf8;
    return {};
}

std::string URIUnescape( const std::string &_escaped )
{
    if( auto str = [NSString stringWithUTF8StdString:_escaped] )
        if( auto stripped = [str stringByRemovingPercentEncoding] )
            if( auto utf8 = stripped.UTF8String )
                return utf8;
    return {};
}

std::string URIForPath(const HostConfiguration& _options, const std::string &_path)
{
    auto uri = _options.full_url;
    if( _path != "/" ) {
        uri.pop_back();
        uri += URIEscape(_path);
    }
    return uri;
}

}
