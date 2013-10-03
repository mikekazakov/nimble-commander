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

static NSString *const g_Domain = @"info.filesmanager.files.vfs";

int VFSError::FromErrno(int _errno)
{
    assert(_errno >= 1 && _errno < 200); // actually 106 was max
    return -(1001 + _errno);
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

static NSString *TextForCode(int _code)
{
    // TODO later: localization
    switch (_code) {
        case VFSError::Ok:                  return @"No error";
        case VFSError::Cancelled:           return @"Operation was cancelled";
        case VFSError::NotSupported:        return @"Operation is not supported";
        case VFSError::InvalidCall:         return @"Invalid call";
        case VFSError::GenericError:        return @"Generic error";
        case VFSError::NotFound:            return @"Item not found";
        case VFSError::UnexpectedEOF:       return @"An unexpected end of file occured";
        case VFSError::ArclibFileFormat:    return @"Unrecognized or invalid archive file format";
        case VFSError::ArclibProgError:     return @"Internal archive module error";
        case VFSError::ArclibMiscError:     return @"Unknown or unclassified archive error";
    }
    return @"Unknown error";
}

NSError* VFSError::ToNSError(int _code)
{
    if(_code <= -1001 && _code >= -1200)
        // unix error codes section
        return [NSError errorWithDomain:NSPOSIXErrorDomain code:(-_code - 1001) userInfo:nil];
    
    // general codes section
    return [NSError errorWithDomain:g_Domain
                               code:_code
                           userInfo:@{ NSLocalizedDescriptionKey : TextForCode(_code) }
            ];
}
