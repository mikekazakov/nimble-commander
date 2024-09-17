// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>

namespace nc::vfs::webdav {

class HostConfiguration;

std::pair<std::string, std::string> DeconstructPath(std::string_view _path); // {"/directory/", "filename"}
std::string URIEscape(std::string_view _unescaped);
std::string URIUnescape(const std::string &_escaped);
std::string URIForPath(const HostConfiguration &_options, std::string_view _path);

} // namespace nc::vfs::webdav
