// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/PathManip.h>
#include <cassert>
#include <cstdlib>
#include <cstring>

bool EliminateTrailingSlashInPath(char *_path)
{
    if( _path == nullptr )
        return false;

    size_t len = strlen(_path);
    if( len == 0 || _path[0] != '/' )
        return false;

    if( len == 1 )
        return true;

    if( _path[len - 1] == '/' )
        _path[len - 1] = 0;

    return true;
}

bool GetFilenameFromPath(const char *_path, char *_buf)
{
    if( _path[0] != '/' )
        return false;
    const char *last_sl = strrchr(_path, '/');
    if( !last_sl )
        return false;
    if( last_sl == _path + strlen(_path) - 1 )
        return false;
    strcpy(_buf, last_sl + 1);
    return true;
}

bool GetDirectoryContainingItemFromPath(const char *_path, char *_buf)
{
    if( _path[0] != '/' )
        return false;
    size_t sz = strlen(_path);
    if( sz == 1 )
        return false;

    const char *last_sl = strrchr(_path, '/');
    if( last_sl == _path + sz - 1 )
        while( *(--last_sl) != '/' )
            ;
    memcpy(_buf, _path, last_sl - _path + 1);
    _buf[last_sl - _path + 1] = 0;
    return true;
}

bool GetFilenameFromRelPath(const char *_path, char *_buf)
{
    const char *last_sl = strrchr(_path, '/');
    if( last_sl == nullptr ) {
        strcpy(_buf, _path); // assume that there's no directories in this path, so return the entire original path
        return true;
    }
    else {
        if( last_sl == _path + strlen(_path) - 1 )
            return false; // don't handle paths like "Dir/"
        strcpy(_buf, last_sl + 1);
        return true;
    }
}

bool GetDirectoryContainingItemFromRelPath(const char *_path, char *_buf)
{
    const char *last_sl = strrchr(_path, '/');
    if( !last_sl ) {
        _buf[0] = 0;
        return true;
    }
    memcpy(_buf, _path, last_sl - _path + 1);
    _buf[last_sl - _path + 1] = 0;
    return true;
}

bool GetExtensionFromPath(const char *_path, char *_buf)
{
    const char *last_sl = strrchr(_path, '/');
    const char *last_dot = strrchr(_path, '.');
    if( !last_sl || !last_dot )
        return false;
    if( last_dot == last_sl + 1 )
        return false;
    if( last_dot == _path + strlen(_path) - 1 )
        return false;
    if( last_dot < last_sl )
        return false;
    strcpy(_buf, last_dot + 1);
    return true;
}

bool GetExtensionFromRelPath(const char *_path, char *_buf)
{
    const char *last_sl = strrchr(_path, '/');
    const char *last_dot = strrchr(_path, '.');
    if( last_dot == nullptr )
        return false;

    if( last_sl ) {
        if( last_dot == last_sl + 1 )
            return false;
        if( last_dot == _path + strlen(_path) - 1 )
            return false;
        if( last_dot < last_sl )
            return false;
        strcpy(_buf, last_dot + 1);
        return true;
    }
    else {
        if( last_dot == _path )
            return false;
        if( last_dot == _path + strlen(_path) - 1 )
            return false;
        strcpy(_buf, last_dot + 1);
        return true;
    }
}

bool GetDirectoryNameFromPath(const char *_path, char *_dir_out, [[maybe_unused]] size_t _dir_size)
{
    const char *second_sep = strrchr(_path, '/');
    if( !second_sep )
        return false;

    // Path contains single / in the beginning.
    if( second_sep == _path ) {
        assert(_dir_size >= 2);
        _dir_out[0] = '/';
        _dir_out[1] = 0;
        return true;
    }

    // Searching for the second separator.
    const char *first_sep = second_sep - 1;
    for( ; first_sep != _path && *first_sep != '/'; --first_sep )
        ;

    if( *first_sep != '/' ) {
        // Peculiar situation. Path contains only one /, and it is in the middle of the path.
        // Assume that directory name is part of the path located to the left of the /.
        first_sep = _path - 1;
    }

    size_t len = second_sep - first_sep - 1;
    assert(len + 1 <= _dir_size);
    memcpy(_dir_out, first_sep + 1, len);
    _dir_out[len + 1] = 0;

    return true;
}

namespace nc::utility {

bool PathManip::IsAbsolute(std::string_view _path) noexcept
{
    return _path.length() > 0 && _path.front() == '/';
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
