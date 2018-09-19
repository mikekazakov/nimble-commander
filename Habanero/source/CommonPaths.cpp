/* Copyright (c) 2013-2016 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#include <CoreFoundation/CoreFoundation.h>
#include <sys/param.h>
#include <pwd.h>
#include <unistd.h>
#include <Habanero/CommonPaths.h>

namespace CommonPaths
{

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

const std::string &AppBundle() noexcept
{
    static const auto path = ensure_tr_slash(GetMainBundlePath());
    return path;
}

const std::string &Home() noexcept
{
    static const auto path = ensure_tr_slash(getpwuid(getuid())->pw_dir);
    return path;
}

const std::string &Documents() noexcept
{
    static const auto path = Home() + "Documents/";
    return path;
}

const std::string &Desktop() noexcept
{
    static const auto path = Home() + "Desktop/";
    return path;
}

const std::string &Downloads() noexcept
{
    static const auto path = Home() + "Downloads/";
    return path;
}

const std::string &Applications() noexcept
{
    static const auto path = std::string("/Applications/");
    return path;
}

const std::string &Utilities() noexcept
{
    static const auto path = std::string("/Applications/Utilities/");
    return path;
}

const std::string &Library() noexcept
{
    static const auto path = Home() + "Library/";
    return path;
}

const std::string &Pictures() noexcept
{
    static const auto path = Home() + "Pictures/";
    return path;
}

const std::string &Music() noexcept
{
    static const auto path = Home() + "Music/";
    return path;
}

const std::string &Movies() noexcept
{
    static const auto path = Home() + "Movies/";
    return path;
}

const std::string &Root() noexcept
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
const std::string &StartupCWD() noexcept
{
    return g_StartupCWD;
}
    
}
