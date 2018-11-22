// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>

namespace nc::vfs::webdav {

class HostConfiguration;

std::pair<std::string, std::string>
    DeconstructPath(const std::string &_path); // {"/directory/", "filename"}
std::string URIEscape( const std::string &_unescaped );
std::string URIUnescape( const std::string &_escaped );
std::string URIForPath(const HostConfiguration& _options, const std::string &_path);

}
