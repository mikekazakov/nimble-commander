// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <filesystem>

/**
 * Converts path like "/Dir/Abra/" to "/Dir/Abra".
 * Will preserve "/" as "/".
 * Will return false on NULL and on empty paths and on paths not starting with slash.
 */
bool EliminateTrailingSlashInPath(char *_path);

/**
 * GetFilenameFromPath assumes that _path is absolute and there's a leading slash in it.
 * Also assume, that it is not a directory path, like /Dir/, it will return false on such case.
 */
bool GetFilenameFromPath(const char *_path, char *_buf);

/**
 * GetDirectoryNameFromPath returns a rightmost directory name.
 * Assuming that path has a form /Abra/Cadabra/ or /Abra/Cadabra/1.txt, function will return
 * Cadabra.
 */
bool GetDirectoryNameFromPath(const char *_path, char *_dir_out, size_t _dir_size);

/**
 * GetDirectoryContainingItemFromPath will parse path like /Dir/wtf and return /Dir/.
 * For paths like /Dir/wtf/ will return /Dir/.
 * Will return false on relative paths.
 */
bool GetDirectoryContainingItemFromPath(const char *_path, char *_buf);

/**
 * GetFilenameFromRelPath can work with relative paths like "Filename".
 */
bool GetFilenameFromRelPath(const char *_path, char *_buf);

/**
 * GetDirectoryContainingItemFromRelPath can work on paths like "Filename", will simply return "".
 * Assume that it's not a directory path like "/Dir/"
 */
bool GetDirectoryContainingItemFromRelPath(const char *_path, char *_buf);

/**
 * GetExtensionFromPath works with absolute paths and will not work with some relative paths like
 * "filename.txt". It will not extract extensions from filenames like ".filename" or "filename."
 */
bool GetExtensionFromPath(const char *_path, char *_buf);

/**
 * GetExtensionFromRelPath can work with absolute path and paths like "filename.txt"
 * It will not extract extensions from filenames like ".filename" or "filename."
 */
bool GetExtensionFromRelPath(const char *_path, char *_buf);

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
    static bool HasTrailingSlash(std::string_view _path) noexcept;

    // Returns the path without trailing slashes. NB! The root path "/" will be returned as-is.
    static std::string_view WithoutTrailingSlashes(std::string_view _path) noexcept;

    // Returns the filename portion of the path.
    static std::string_view Filename(std::string_view _path) noexcept;

    // Returns the extension of the filename portion of the path.
    static std::string_view Extension(std::string_view _path) noexcept;

    // Returns the parent path of the path.
    static std::string_view Parent(std::string_view _path) noexcept;

    static std::filesystem::path Expand(std::string_view _path, std::string_view _home, std::string_view _cwd) noexcept;
    static std::filesystem::path EnsureTrailingSlash(std::filesystem::path _path) noexcept;
};

} // namespace nc::utility
