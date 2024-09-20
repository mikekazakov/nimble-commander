// Copyright (C) 2013-2024 Michael G. Kazakov. Subject to GNU General Public License version 3.
#include <CoreFoundation/CoreFoundation.h>
#include <sys/param.h>
#include <pwd.h>
#include <unistd.h>
#include <Base/CommonPaths.h>

namespace nc::base {

static std::string cwd();
static std::string ensure_tr_slash(std::string _str);
static std::string GetMainBundlePath();

[[clang::no_destroy]] static const std::string g_StartupCWD = ensure_tr_slash(cwd());

static std::string GetMainBundlePath()
{
    CFURLRef url = CFBundleCopyBundleURL(CFBundleGetMainBundle());
    char path[MAXPATHLEN];
    const bool result = CFURLGetFileSystemRepresentation(url, true, reinterpret_cast<UInt8 *>(path), MAXPATHLEN);
    CFRelease(url);
    return result ? std::string(path) : std::string("");
}

static std::string ensure_tr_slash(std::string _str)
{
    if( _str.empty() || _str.back() != '/' )
        _str += '/';
    return _str;
}

const std::string &CommonPaths::AppBundle() noexcept
{
    [[clang::no_destroy]] static const auto path = ensure_tr_slash(GetMainBundlePath());
    return path;
}

const std::string &CommonPaths::Home() noexcept
{
    [[clang::no_destroy]] static const auto path = ensure_tr_slash(getpwuid(getuid())->pw_dir);
    return path;
}

const std::string &CommonPaths::Documents() noexcept
{
    [[clang::no_destroy]] static const auto path = Home() + "Documents/";
    return path;
}

const std::string &CommonPaths::Desktop() noexcept
{
    [[clang::no_destroy]] static const auto path = Home() + "Desktop/";
    return path;
}

const std::string &CommonPaths::Downloads() noexcept
{
    [[clang::no_destroy]] static const auto path = Home() + "Downloads/";
    return path;
}

const std::string &CommonPaths::Applications() noexcept
{
    [[clang::no_destroy]] static const auto path = std::string("/Applications/");
    return path;
}

const std::string &CommonPaths::Utilities() noexcept
{
    [[clang::no_destroy]] static const auto path = std::string("/Applications/Utilities/");
    return path;
}

const std::string &CommonPaths::Library() noexcept
{
    [[clang::no_destroy]] static const auto path = Home() + "Library/";
    return path;
}

const std::string &CommonPaths::Pictures() noexcept
{
    [[clang::no_destroy]] static const auto path = Home() + "Pictures/";
    return path;
}

const std::string &CommonPaths::Music() noexcept
{
    [[clang::no_destroy]] static const auto path = Home() + "Music/";
    return path;
}

const std::string &CommonPaths::Movies() noexcept
{
    [[clang::no_destroy]] static const auto path = Home() + "Movies/";
    return path;
}

const std::string &CommonPaths::Root() noexcept
{
    [[clang::no_destroy]] static const auto path = std::string("/");
    return path;
}

static std::string cwd()
{
    char cwd[MAXPATHLEN];
    getcwd(cwd, MAXPATHLEN);
    return cwd;
}

const std::string &CommonPaths::StartupCWD() noexcept
{
    return g_StartupCWD;
}

} // namespace nc::base
