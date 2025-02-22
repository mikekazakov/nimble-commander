// Copyright (C) 2020-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Host.h"

namespace nc::vfs::native {

// Fetches listing for _system_path.
// Checks if _user_path exists and is a directory,
// fetches that listing as well and returns a combined listing.
// Otherwise returns only the listing for _system_path.
std::expected<VFSListingPtr, Error> FetchUnifiedListing(NativeHost &_host,
                                                        std::string_view _system_path,
                                                        std::string_view _user_path,
                                                        unsigned long _flags,
                                                        const VFSCancelChecker &_cancel_checker = {});

std::expected<VFSListingPtr, Error>
FetchUnifiedApplicationsListing(NativeHost &_host, unsigned long _flags, const VFSCancelChecker &_cancel_checker = {});

std::expected<VFSListingPtr, Error>
FetchUnifiedUtilitiesListing(NativeHost &_host, unsigned long _flags, const VFSCancelChecker &_cancel_checker = {});

} // namespace nc::vfs::native
