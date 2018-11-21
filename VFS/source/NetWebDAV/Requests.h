// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Internal.h"

namespace nc::vfs::webdav {

std::pair<int, HTTPRequests::Mask> RequestServerOptions(const HostConfiguration& _options,
                                                        Connection &_connection );

// vfs error, free space, used space
std::tuple<int, long, long> RequestSpaceQuota(const HostConfiguration& _options,
                                              Connection &_connection );

std::pair<int, std::vector<PropFindResponse>> RequestDAVListing(const HostConfiguration& _options,
                                                                Connection &_connection,
                                                                const std::string &_path );

int RequestMKCOL(const HostConfiguration& _options,
                 Connection &_connection,
                 const std::string &_path );
    
int RequestDelete(const HostConfiguration& _options,
                  Connection &_connection,
                  const std::string &_path );

int RequestMove(const HostConfiguration& _options,
                Connection &_connection,
                const std::string &_src,
                const std::string &_dst );

}
