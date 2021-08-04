// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WhereIs.h"
#include <cstdlib>
#include <boost/algorithm/string/split.hpp>

namespace nc::base {

static std::vector<std::filesystem::path> GetDirectories()
{
    const std::string path = std::getenv("PATH");
    std::vector<std::string> parts;
    boost::split(
        parts, path, [](char _c) { return _c == ':'; }, boost::token_compress_on);
    std::vector<std::filesystem::path> result(parts.begin(), parts.end());
    return result;
}

std::vector<std::filesystem::path> WhereIs(std::string_view name)
{
    if( name.empty() )
        return {};
    if( name.find('/') != name.npos )
        return {};

    const auto directories = GetDirectories();
    std::vector<std::filesystem::path> found;
    for( const auto &directory : directories ) {
        for( const auto &entry : std::filesystem::directory_iterator(directory) ) {
            if( entry.path().filename() != name )
                continue;
            const auto status = entry.status();
            const auto any_exec = std::filesystem::perms::owner_exec |
                                  std::filesystem::perms::group_exec |
                                  std::filesystem::perms::others_exec;
            if( std::filesystem::is_regular_file(status) &&
                (status.permissions() & any_exec) != std::filesystem::perms::none ) {
                found.emplace_back(entry.path());
            }
        }
    }
    return found;
}

} // namespace nc::base
