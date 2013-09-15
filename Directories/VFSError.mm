//
//  VFSError.mm
//  Files
//
//  Created by Michael G. Kazakov on 14.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/errno.h>
#import "3rd_party/libarchive/archive_platform.h"
#import "VFSError.h"

int VFSError::FromErrno(int _errno)
{
    assert(_errno >= 1 && _errno < 200); // actually 106 was max
    return -1001 - _errno;
}

int VFSError::FromLibarchive(int _errno)
{
    if(_errno == ARCHIVE_ERRNO_FILE_FORMAT)
        return VFSError::ArclibFileFormat;
    else if(_errno == ARCHIVE_ERRNO_PROGRAMMER)
        return VFSError::ArclibProgError;
    else if(_errno == ARCHIVE_ERRNO_MISC)
        return VFSError::ArclibMiscError;
    
    return FromErrno(_errno); // if error is none of listed above - treat it as unix error code
}

NSError* VFSError::ToNSError(int _code)
{
    
    return nil;
}
