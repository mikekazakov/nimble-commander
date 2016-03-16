#include <Foundation/Foundation.h>
#include <Habanero/CommonPaths.h>

namespace CommonPaths
{

static std::string ensure_tr_slash( std::string _str )
{
    if(_str.empty() || _str.back() != '/')
        _str += '/';
    return _str;
}
    
const std::string &AppTemporaryDirectory() noexcept
{
    static auto path = ensure_tr_slash( NSTemporaryDirectory().fileSystemRepresentation );
    return path;
}

}
