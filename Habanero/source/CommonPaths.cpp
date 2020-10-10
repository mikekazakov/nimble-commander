// Copyright (C) 2013-2020 Michael G. Kazakov. Subject to GNU General Public License version 3.
#include <CoreFoundation/CoreFoundation.h>
#include <sys/param.h>
#include <pwd.h>
#include <unistd.h>
#include <Habanero/CommonPaths.h>

namespace nc::base {

static std::string GetMainBundlePath()
{
    CFURLRef url = CFBundleCopyBundleURL(CFBundleGetMainBundle());
    char path[MAXPATHLEN];
    bool result = CFURLGetFileSystemRepresentation(url, true, (UInt8*)path, MAXPATHLEN);
    CFRelease(url);
    return result ? std::string(path) : std::string("");
}

static std::string ensure_tr_slash( std::string _str )
{
    if( _str.empty() || _str.back() != '/' )
        _str += '/';
    return _str;
}

const std::string &CommonPaths::AppBundle() noexcept
{
    static const auto path = ensure_tr_slash(GetMainBundlePath());
    return path;
}

const std::string &CommonPaths::Home() noexcept
{
    static const auto path = ensure_tr_slash(getpwuid(getuid())->pw_dir);
    return path;
}

const std::string &CommonPaths::Documents() noexcept
{
    static const auto path = Home() + "Documents/";
    return path;
}

const std::string &CommonPaths::Desktop() noexcept
{
    static const auto path = Home() + "Desktop/";
    return path;
}

const std::string &CommonPaths::Downloads() noexcept
{
    static const auto path = Home() + "Downloads/";
    return path;
}

const std::string &CommonPaths::Applications() noexcept
{
    static const auto path = std::string("/Applications/");
    return path;
}

const std::string &CommonPaths::Utilities() noexcept
{
    static const auto path = std::string("/Applications/Utilities/");
    return path;
}

const std::string &CommonPaths::Library() noexcept
{
    static const auto path = Home() + "Library/";
    return path;
}

const std::string &CommonPaths::Pictures() noexcept
{
    static const auto path = Home() + "Pictures/";
    return path;
}

const std::string &CommonPaths::Music() noexcept
{
    static const auto path = Home() + "Music/";
    return path;
}

const std::string &CommonPaths::Movies() noexcept
{
    static const auto path = Home() + "Movies/";
    return path;
}

const std::string &CommonPaths::Root() noexcept
{
    static const auto path = std::string("/");
    return path;
}

static std::string cwd()
{
    char cwd[MAXPATHLEN];
    getcwd(cwd, MAXPATHLEN);
    return cwd;
}

static const std::string g_StartupCWD = ensure_tr_slash( cwd() );
const std::string &CommonPaths::StartupCWD() noexcept
{
    return g_StartupCWD;
}
    
}
