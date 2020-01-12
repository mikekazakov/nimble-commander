// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.

#include "SpecialDirectories.h"
#include <VFS/VFSListingInput.h>
#include <Utility/SystemInformation.h>
#include <sys/errno.h>
#include <cassert>

namespace nc::vfs::native {

static const auto g_SystemApplications = "/System/Applications";
static const auto g_UserApplications = "/Applications"; 
static const auto g_SystemUtilities = "/System/Applications/Utilities";
static const auto g_UserUtilities = "/Applications/Utilities"; 


int FetchUnifiedListing(NativeHost& _host,
                        const char *_system_path,
                        const char *_user_path,
                        VFSListingPtr &_target,
                        unsigned long _flags,
                        const VFSCancelChecker &_cancel_checker)
{
    try {
        _flags = _flags | VFSFlags::F_NoDotDot;
        
        VFSListingPtr system_listing;
        const int fetch_system_rc =  _host.FetchDirectoryListing(_system_path,
                                                                 system_listing,
                                                                 _flags,
                                                                 _cancel_checker);
        if( fetch_system_rc != VFSError::Ok )
            return fetch_system_rc; 
        
        if( _host.Exists(_user_path, _cancel_checker) &&
           _host.IsDirectory(_user_path, VFSFlags::None) ) {
            VFSListingPtr user_listing;
            const int fetch_user_rc =  _host.FetchDirectoryListing(_user_path,
                                                                   user_listing,
                                                                   _flags,
                                                                   _cancel_checker);
            if( fetch_user_rc != VFSError::Ok )
                return fetch_user_rc;             
            _target = Listing::Build(Listing::Compose({system_listing, user_listing}));    
        }
        else {
            _target = system_listing;
        }
    }
    catch(VFSErrorException err) {
        return err.code();
    }
    catch(...) {
        return VFSError::FromErrno(EINVAL);
    }
    return VFSError::Ok;
}

int FetchUnifiedApplicationsListing(NativeHost& _host,
                                    VFSListingPtr &_target,
                                    unsigned long _flags,
                                    const VFSCancelChecker &_cancel_checker)
{
    assert( utility::GetOSXVersion() >= utility::OSXVersion::OSX_15 );
    return FetchUnifiedListing(_host,
                               g_SystemApplications,
                               g_UserApplications,
                               _target,
                               _flags,
                               _cancel_checker);
}

int FetchUnifiedUtilitiesListing(NativeHost& _host,
                                 VFSListingPtr &_target,
                                 unsigned long _flags,
                                 const VFSCancelChecker &_cancel_checker)
{
    assert( utility::GetOSXVersion() >= utility::OSXVersion::OSX_15 );
    return FetchUnifiedListing(_host,
                               g_SystemUtilities,
                               g_UserUtilities,
                               _target,
                               _flags,
                               _cancel_checker);
}

}
