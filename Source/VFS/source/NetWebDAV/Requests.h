// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Internal.h"
#include <vector>

namespace nc::vfs::webdav {

std::expected<HTTPRequests::Mask, Error> RequestServerOptions(const HostConfiguration &_options,
                                                              Connection &_connection);

// vfs error, free space, used space
struct SpaceQuota {
    int64_t free = 0;
    int64_t used = 0;
};
std::expected<SpaceQuota, Error> RequestSpaceQuota(const HostConfiguration &_options, Connection &_connection);

std::expected<std::vector<PropFindResponse>, Error>
RequestDAVListing(const HostConfiguration &_options, Connection &_connection, const std::string &_path);

std::expected<void, Error>
RequestMKCOL(const HostConfiguration &_options, Connection &_connection, const std::string &_path);

std::expected<void, Error>
RequestDelete(const HostConfiguration &_options, Connection &_connection, std::string_view _path);

std::expected<void, Error> RequestMove(const HostConfiguration &_options,
                                       Connection &_connection,
                                       const std::string &_src,
                                       const std::string &_dst);

} // namespace nc::vfs::webdav
