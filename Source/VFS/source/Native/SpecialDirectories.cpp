// Copyright (C) 2020-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SpecialDirectories.h"
#include "DisplayNamesCache.h"
#include <VFS/VFSListingInput.h>
#include <Utility/SystemInformation.h>
#include <sys/errno.h>
#include <cassert>

namespace nc::vfs::native {

static const auto g_SystemApplications = "/System/Applications";
static const auto g_UserApplications = "/Applications";
static const auto g_SystemUtilities = "/System/Applications/Utilities";
static const auto g_UserUtilities = "/Applications/Utilities";

static const char *MakeNonLocalizedTitle(const char *_from)
{
    if( _from == nullptr )
        return nullptr;
    auto p = strrchr(_from, '/');
    return p ? p + 1 : nullptr;
}

int FetchUnifiedListing(NativeHost &_host,
                        const char *_system_path,
                        const char *_user_path,
                        VFSListingPtr &_target,
                        unsigned long _flags,
                        const VFSCancelChecker &_cancel_checker)
{
    try {
        _flags = _flags | VFSFlags::F_NoDotDot;

        VFSListingPtr system_listing;
        const int fetch_system_rc = _host.FetchDirectoryListing(_system_path, system_listing, _flags, _cancel_checker);
        if( fetch_system_rc != VFSError::Ok )
            return fetch_system_rc;

        if( _host.Exists(_user_path, _cancel_checker) && _host.IsDirectory(_user_path, VFSFlags::None) ) {
            VFSListingPtr user_listing;
            const int fetch_user_rc = _host.FetchDirectoryListing(_user_path, user_listing, _flags, _cancel_checker);
            if( fetch_user_rc != VFSError::Ok )
                return fetch_user_rc;

            auto input = Listing::Compose({system_listing, user_listing});

            if( (_flags & VFSFlags::F_LoadDisplayNames) != 0 ) {
                auto &cache = DisplayNamesCache::Instance();
                if( auto userpath_name = cache.DisplayName(_user_path) )
                    input.title = *userpath_name;
                else if( auto systempath_name = cache.DisplayName(_system_path) )
                    input.title = *systempath_name;
                else if( auto nonloc_name = MakeNonLocalizedTitle(_user_path) )
                    input.title = nonloc_name;
            }
            else {
                if( auto name = MakeNonLocalizedTitle(_user_path) )
                    input.title = name;
            }

            _target = Listing::Build(std::move(input));
        }
        else {
            _target = system_listing;
        }
    } catch( const ErrorException & /*err*/ ) {
        return VFSError::FromErrno(EINVAL); // TODO: return err
    } catch( ... ) {
        return VFSError::FromErrno(EINVAL);
    }
    return VFSError::Ok;
}

int FetchUnifiedApplicationsListing(NativeHost &_host,
                                    VFSListingPtr &_target,
                                    unsigned long _flags,
                                    const VFSCancelChecker &_cancel_checker)
{
    assert(utility::GetOSXVersion() >= utility::OSXVersion::OSX_15);
    return FetchUnifiedListing(_host, g_SystemApplications, g_UserApplications, _target, _flags, _cancel_checker);
}

int FetchUnifiedUtilitiesListing(NativeHost &_host,
                                 VFSListingPtr &_target,
                                 unsigned long _flags,
                                 const VFSCancelChecker &_cancel_checker)
{
    assert(utility::GetOSXVersion() >= utility::OSXVersion::OSX_15);
    return FetchUnifiedListing(_host, g_SystemUtilities, g_UserUtilities, _target, _flags, _cancel_checker);
}

} // namespace nc::vfs::native
