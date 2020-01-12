// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Host.h"

namespace nc::vfs::native {

// Fetches listing for _system_path.
// Checks if _user_path exists and is a directory,
// fetches that listing as well and returns a combined listing.
// Otherwise returns only the listing for _system_path.
int FetchUnifiedListing(NativeHost& _host,
                        const char *_system_path,
                        const char *_user_path,
                        VFSListingPtr &_target,
                        unsigned long _flags,
                        const VFSCancelChecker &_cancel_checker);

int FetchUnifiedApplicationsListing(NativeHost& _host,
                                    VFSListingPtr &_target,
                                    unsigned long _flags,
                                    const VFSCancelChecker &_cancel_checker);

int FetchUnifiedUtilitiesListing(NativeHost& _host,
                                 VFSListingPtr &_target,
                                 unsigned long _flags,
                                 const VFSCancelChecker &_cancel_checker);

}
