// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <filesystem>

// prefer PathManip::EnsureTrailingSlash() instead, semantically equal
inline std::string EnsureTrailingSlash(std::string _s)
{
    if( !_s.empty() && _s.back() != '/' )
        _s.push_back('/');
    return _s;
}

inline std::string EnsureNoTrailingSlash(std::string _s)
{
    while( _s.length() > 1 && _s.back() == '/' )
        _s.pop_back();
    return _s;
}

namespace nc::utility {

struct PathManip {
    // Returns true if the path starts with a forward slash.
    static bool IsAbsolute(std::string_view _path) noexcept;

    // Returns true if the path ends with a forward slash.
    // Will return true on the root "/" path.
    static bool HasTrailingSlash(std::string_view _path) noexcept;

    // Returns the path without trailing slashes. NB! The root path "/" will be returned as-is.
    static std::string_view WithoutTrailingSlashes(std::string_view _path) noexcept;

    // Returns the filename portion of the path.
    static std::string_view Filename(std::string_view _path) noexcept;

    // Returns the extension of the filename portion of the path.
    static std::string_view Extension(std::string_view _path) noexcept;

    // Returns the parent path of the path.
    // Includes a trailing slash.
    static std::string_view Parent(std::string_view _path) noexcept;

    static std::filesystem::path Expand(std::string_view _path, std::string_view _home, std::string_view _cwd) noexcept;
    static std::filesystem::path EnsureTrailingSlash(std::filesystem::path _path) noexcept;
};

} // namespace nc::utility
