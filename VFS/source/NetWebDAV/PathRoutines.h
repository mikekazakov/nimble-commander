// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::vfs::webdav {

class HostConfiguration;

pair<string, string> DeconstructPath(const string &_path); // {"/directory/", "filename"}
string URIEscape( const string &_unescaped );
string URIUnescape( const string &_escaped );
string URIForPath(const HostConfiguration& _options, const string &_path);

}
