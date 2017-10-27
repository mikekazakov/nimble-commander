// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Internal.h"

namespace nc::vfs::webdav {

pair<int, HTTPRequests::Mask> RequestServerOptions(const HostConfiguration& _options,
                                                 Connection &_connection );

// vfs error, free space, used space
tuple<int, long, long> RequestSpaceQuota(const HostConfiguration& _options,
                                         Connection &_connection );

pair<int, vector<PropFindResponse>> RequestDAVListing(const HostConfiguration& _options,
                                                    Connection &_connection,
                                                    const string &_path );

int RequestMKCOL(const HostConfiguration& _options,
                 Connection &_connection,
                 const string &_path );
    
int RequestDelete(const HostConfiguration& _options,
                  Connection &_connection,
                  const string &_path );

int RequestMove(const HostConfiguration& _options,
                Connection &_connection,
                const string &_src,
                const string &_dst );

}
