// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/PathManip.h>
#include <cassert>
#include <cstdlib>
#include <cstring>

namespace nc::utility {

bool PathManip::IsAbsolute(std::string_view _path) noexcept
{
    return _path.starts_with('/');
}

bool PathManip::HasTrailingSlash(std::string_view _path) noexcept
{
    return _path.ends_with('/');
}

std::string_view PathManip::WithoutTrailingSlashes(std::string_view _path) noexcept
{
    while( _path.size() > 1 && _path.back() == '/' ) {
        _path.remove_suffix(1);
    }
    return _path;
}

std::string_view PathManip::Filename(std::string_view _path) noexcept
{
    const char *const first = _path.data();
    const char *last = first + _path.size();

    while( last > first && last[-1] == '/' )
        --last;

    const char *filename = last;
    while( filename > first && filename[-1] != '/' )
        --filename;

    return {filename, static_cast<size_t>(last - filename)};
}

std::string_view PathManip::Extension(std::string_view _path) noexcept
{
    _path = Filename(_path);

    const char *const first = _path.data();
    const char *last = first + _path.size();

    // scan until we meet a first non-period
    const char *extension = last;
    while( extension > first && extension[-1] == '.' )
        --extension;

    // scan until we meet a period
    while( extension > first && extension[-1] != '.' )
        --extension;

    if( extension == first )
        return {}; // didn't found a period

    if( extension == first + 1 )
        return {}; // don't allow e.g. ".foo"

    return {extension, static_cast<size_t>(last - extension)};
}

std::string_view PathManip::Parent(std::string_view _path) noexcept
{
    const char *const first = _path.data();
    const char *last = first + _path.size();

    while( last > first && last[-1] == '/' )
        --last;

    while( last > first && last[-1] != '/' )
        --last;

    return {first, static_cast<size_t>(last - first)};
}

std::filesystem::path PathManip::Expand(std::string_view _path, std::string_view _home, std::string_view _cwd) noexcept
{
    if( _home.empty() )
        _home = "/";
    if( _cwd.empty() )
        _cwd = "/";

    if( _path.empty() ) {
        // empty path - return empty
        return {};
    }
    else if( _path.front() == '/' ) {
        // absolute path - normalize and return
        return std::filesystem::path(_path).lexically_normal();
    }
    else if( _path.front() == '~' ) {
        // relative to home path - concatenate, normalize and return
        _path.remove_prefix(1);
        std::string result;
        result.reserve(_home.size() + _path.size() + 1);
        result += _home;
        if( result.back() == '/' ) {
            result += _path;
        }
        else {
            if( _path.empty() || _path.front() != '/' )
                result += '/';
            result += _path;
        }
        return std::filesystem::path(result).lexically_normal();
    }
    else {
        // relative to cwd path - concatenate, normalize and return
        std::string result;
        result.reserve(_cwd.size() + _path.size() + 1);
        result += _cwd;
        if( result.back() == '/' ) {
            result += _path;
        }
        else {
            if( _path.front() != '/' )
                result += '/';
            result += _path;
        }
        return std::filesystem::path(result).lexically_normal();
    }
}

std::filesystem::path PathManip::EnsureTrailingSlash(std::filesystem::path _path) noexcept
{
    if( !_path.empty() && _path.native().back() != '/' )
        _path += '/';
    return _path;
}

} // namespace nc::utility
