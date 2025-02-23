// Copyright (C) 2020-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SpecialDirectories.h"
#include "DisplayNamesCache.h"
#include <VFS/VFSListingInput.h>
#include <Utility/SystemInformation.h>
#include <sys/errno.h>
#include <cassert>

namespace nc::vfs::native {

static const std::string_view g_SystemApplications = "/System/Applications";
static const std::string_view g_UserApplications = "/Applications";
static const std::string_view g_SystemUtilities = "/System/Applications/Utilities";
static const std::string_view g_UserUtilities = "/Applications/Utilities";

static std::string_view MakeNonLocalizedTitle(const std::string_view _from)
{
    const size_t p = _from.rfind('/');
    if( p == std::string_view::npos )
        return {};
    else
        return _from.substr(p + 1);
}

std::expected<VFSListingPtr, Error> FetchUnifiedListing(NativeHost &_host,
                                                        const std::string_view _system_path,
                                                        const std::string_view _user_path,
                                                        unsigned long _flags,
                                                        const VFSCancelChecker &_cancel_checker)
{
    try {
        _flags = _flags | VFSFlags::F_NoDotDot;

        const std::expected<VFSListingPtr, Error> system_listing =
            _host.FetchDirectoryListing(_system_path, _flags, _cancel_checker);
        if( !system_listing )
            return system_listing;

        if( _host.Exists(_user_path, _cancel_checker) && _host.IsDirectory(_user_path, VFSFlags::None) ) {
            const std::expected<VFSListingPtr, Error> user_listing =
                _host.FetchDirectoryListing(_user_path, _flags, _cancel_checker);
            if( !user_listing )
                return user_listing;

            auto input = Listing::Compose({*system_listing, *user_listing});

            if( (_flags & VFSFlags::F_LoadDisplayNames) != 0 ) {
                auto &cache = DisplayNamesCache::Instance();
                if( auto userpath_name = cache.DisplayName(_user_path) )
                    input.title = *userpath_name;
                else if( auto systempath_name = cache.DisplayName(_system_path) )
                    input.title = *systempath_name;
                else if( auto nonloc_name = MakeNonLocalizedTitle(_user_path); !nonloc_name.empty() )
                    input.title = nonloc_name;
            }
            else {
                if( auto name = MakeNonLocalizedTitle(_user_path); !name.empty() )
                    input.title = name;
            }

            return Listing::Build(std::move(input));
        }
        else {
            return system_listing;
        }
    } catch( const ErrorException &err ) {
        return std::unexpected(err.error());
    } catch( ... ) {
        return std::unexpected(Error{Error::POSIX, EINVAL});
    }
}

std::expected<VFSListingPtr, Error>
FetchUnifiedApplicationsListing(NativeHost &_host, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    return FetchUnifiedListing(_host, g_SystemApplications, g_UserApplications, _flags, _cancel_checker);
}

std::expected<VFSListingPtr, Error>
FetchUnifiedUtilitiesListing(NativeHost &_host, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    return FetchUnifiedListing(_host, g_SystemUtilities, g_UserUtilities, _flags, _cancel_checker);
}

} // namespace nc::vfs::native
