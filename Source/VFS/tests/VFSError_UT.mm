// Copyright (C) 2022-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <VFS/VFSError.h>
#include <sys/errno.h>
#include <Cocoa/Cocoa.h>

#define PREFIX "VFSError "

TEST_CASE(PREFIX "FromErrno(int _errno)")
{
    // Check for correct round-trips via NSError
    {
        // 0 is not really an error code, but is still supported for pass-through
        auto nserr = VFSError::ToNSError(VFSError::FromErrno(0));
        REQUIRE(nserr != nil);
        CHECK([nserr.domain isEqualToString:NSPOSIXErrorDomain]);
        CHECK(nserr.code == 0);
    }
    {
        auto nserr = VFSError::ToNSError(VFSError::FromErrno(EPERM));
        REQUIRE(nserr != nil);
        CHECK([nserr.domain isEqualToString:NSPOSIXErrorDomain]);
        CHECK(nserr.code == EPERM);
    }
    {
        auto nserr = VFSError::ToNSError(VFSError::FromErrno(EQFULL));
        REQUIRE(nserr != nil);
        CHECK([nserr.domain isEqualToString:NSPOSIXErrorDomain]);
        CHECK(nserr.code == EQFULL);
    }
    {
        // Ensure that the last Posix error code can be encoded
        auto nserr = VFSError::ToNSError(VFSError::FromErrno(ELAST));
        REQUIRE(nserr != nil);
        CHECK([nserr.domain isEqualToString:NSPOSIXErrorDomain]);
        CHECK(nserr.code == ELAST);
    }
    // Check for invalid inputs - treated as EINVAL
    {
        auto nserr = VFSError::ToNSError(VFSError::FromErrno(-1));
        REQUIRE(nserr != nil);
        CHECK([nserr.domain isEqualToString:NSPOSIXErrorDomain]);
        CHECK(nserr.code == EINVAL);
    }
    {
        auto nserr = VFSError::ToNSError(VFSError::FromErrno(ELAST + 1));
        REQUIRE(nserr != nil);
        CHECK([nserr.domain isEqualToString:NSPOSIXErrorDomain]);
        CHECK(nserr.code == EINVAL);
    }
}

TEST_CASE(PREFIX "FromErrno()")
{
    errno = EIO;
    auto nserr = VFSError::ToNSError(VFSError::FromErrno());
    REQUIRE(nserr != nil);
    CHECK([nserr.domain isEqualToString:NSPOSIXErrorDomain]);
    CHECK(nserr.code == EIO);
    errno = 0;
}
