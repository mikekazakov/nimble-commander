// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PathRoutines.h"
#include "Internal.h"

namespace nc::vfs::webdav {

pair<string, string> DeconstructPath(const string &_path)
{
    if( _path.empty() )
        return {};
    if( _path == "/" )
        return {"/", ".."};
    
    if( _path.back() == '/' ) {
        const auto ls = _path.find_last_of('/', _path.length() - 2);
        if( ls == string::npos )
            return {};
        return { _path.substr(0, ls+1), _path.substr(ls+1, _path.length() - ls - 2) };
    }
    else {
        const auto ls = _path.find_last_of('/');
        if( ls == string::npos )
            return {};
        return { _path.substr(0, ls+1), _path.substr(ls+1) };
    }
}

string URIEscape( const string &_unescaped )
{
    static const auto acs = NSCharacterSet.URLPathAllowedCharacterSet;
    if( auto str = [NSString stringWithUTF8StdString:_unescaped] )
        if( auto percents = [str stringByAddingPercentEncodingWithAllowedCharacters:acs] )
            if( auto utf8 = percents.UTF8String )
                return utf8;
    return {};
}

string URIUnescape( const string &_escaped )
{
    if( auto str = [NSString stringWithUTF8StdString:_escaped] )
        if( auto stripped = [str stringByRemovingPercentEncoding] )
            if( auto utf8 = stripped.UTF8String )
                return utf8;
    return {};
}

string URIForPath(const HostConfiguration& _options, const string &_path)
{
    auto uri = _options.full_url;
    if( _path != "/" ) {
        uri.pop_back();
        uri += URIEscape(_path);
    }
    return uri;
}

}
