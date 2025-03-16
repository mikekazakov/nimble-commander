// Copyright (C) 2013-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/errno.h>
#include <libarchive/archive.h>
#include "../include/VFS/VFSError.h"
#include "../include/VFS/VFSDeclarations.h"
#include "../include/VFS/Log.h"
#include <Foundation/Foundation.h>

static NSString *const g_Domain = @"vfs";

/*
layout:
0                        : OK code
[-1..              -1000]: Files             vfs err = vfs err
[-1'001..         -1'999]: POSIX             vfs err = posix - 1'500
[-1'000'000.. -2'000'000): Cocoa             vfs err = cocoa - 1'500'000
[-2'000'000.. -3'000'000): NSURLError        vfs err = nsurlerror - 2'500'000
 */

static constexpr int g_PosixMax = -1001;
static constexpr int g_PosixBase = -1500;
static constexpr int g_PosixMin = -1999;

namespace VFSError {

static int FromErrno(int _errno) noexcept
{
    if( _errno >= 0 && _errno <= ELAST ) {
        return _errno + g_PosixBase;
    }
    else {
        nc::vfs::Log::Warn("VFSError::FromErrno(): unknown errno - {}", _errno);
        return FromErrno(EINVAL);
    }
}

int FromLibarchive(int _errno)
{
    if( _errno == EFTYPE )
        return VFSError::ArclibFileFormat;
    else if( _errno == EINVAL )
        return VFSError::ArclibProgError;
    else if( _errno == -1 )
        return VFSError::ArclibMiscError;

    return FromErrno(_errno); // if error is none of listed above - treat it as unix error code
}

static NSString *TextForCode(int _code)
{
    // TODO later: localization
    switch( _code ) {
        case Ok:
            return @"No error";
        case InvalidCall:
            return @"Invalid call";
        case GenericError:
            return @"Generic error";
        case NotFound:
            return @"Item not found";
        case ArclibFileFormat:
            return @"Unrecognized or invalid archive file format";
        case ArclibProgError:
            return @"Internal archive module error";
        case ArclibMiscError:
            return @"Unknown or unclassified archive error";
        default:
            return [NSString stringWithFormat:@"Error code %d", _code];
    }
}

// TODO: remove this
static NSError *ToNSError(int _code)
{
    if( _code >= g_PosixMin && _code <= g_PosixMax )
        // unix error codes section
        return [NSError errorWithDomain:NSPOSIXErrorDomain code:(_code - g_PosixBase) userInfo:nil];

    if( _code > -2000000 && _code <= -1000000 )
        return [NSError errorWithDomain:NSCocoaErrorDomain code:(_code + 1500000) userInfo:nil];

    if( _code > -3000000 && _code <= -2000000 )
        return [NSError errorWithDomain:NSURLErrorDomain code:(_code + 2500000) userInfo:nil];

    // general codes section
    return [NSError errorWithDomain:g_Domain code:_code userInfo:@{NSLocalizedDescriptionKey: TextForCode(_code)}];
}

namespace {

// TODO: remove this later
class ErrorDescriptionProvider : public nc::base::ErrorDescriptionProvider
{
public:
    [[nodiscard]] std::string Description(int64_t _code) const noexcept override;
};

// TODO: remove this later
std::string ErrorDescriptionProvider::Description(int64_t _code) const noexcept
{
    return ToNSError(static_cast<int>(_code)).description.UTF8String;
}

} // namespace

// TODO: remove this later
nc::Error ToError(int _vfs_error_code)
{
    static std::once_flag once;
    std::call_once(once,
                   [] { nc::Error::DescriptionProvider(ErrorDomain, std::make_shared<ErrorDescriptionProvider>()); });

    if( _vfs_error_code >= g_PosixMin && _vfs_error_code <= g_PosixMax ) {
        const int posix_code = _vfs_error_code - g_PosixBase;
        return {nc::Error::POSIX, posix_code};
    }

    return {ErrorDomain, _vfs_error_code};
}

} // namespace VFSError
