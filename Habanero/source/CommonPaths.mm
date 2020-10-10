// Copyright (C) 2013-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Foundation/Foundation.h>
#include <Habanero/CommonPaths.h>
#include <stdlib.h>
#include <limits.h>

namespace CommonPaths
{

static std::string RealPath( const char *_path )
{
    assert( _path != nullptr );
    char buf[PATH_MAX+1];
    return realpath(_path, buf);
}

static std::string ensure_tr_slash( std::string _str )
{
    if(_str.empty() || _str.back() != '/')
        _str += '/';
    return _str;
}
    
const std::string &AppTemporaryDirectory() noexcept
{
    static const auto path = new std::string(
        ensure_tr_slash( RealPath(NSTemporaryDirectory().fileSystemRepresentation)) );
    return *path;
}

}
