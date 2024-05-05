// Copyright (C) 2013-2020 Michael G. Kazakov. Subject to GNU General Public License version 3.
#include <Base/CommonPaths.h>
#include <Foundation/Foundation.h>
#include <climits>
#include <cstdlib>

namespace nc::base {

static std::string RealPath(const char *_path)
{
    assert(_path != nullptr);
    char buf[PATH_MAX + 1];
    return realpath(_path, buf);
}

static std::string ensure_tr_slash(std::string _str)
{
    if( _str.empty() || _str.back() != '/' )
        _str += '/';
    return _str;
}

const std::string &CommonPaths::AppTemporaryDirectory() noexcept
{
    static const auto path =
        new std::string(ensure_tr_slash(RealPath(NSTemporaryDirectory().fileSystemRepresentation)));
    return *path;
}

} // namespace nc::base
