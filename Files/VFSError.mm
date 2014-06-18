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

namespace VFSError 
{

int FromErrno(int _errno)
{
    assert(_errno >= 1 && _errno < 200); // actually 106 was max
    return -(1001 + _errno);
}

int FromLibarchive(int _errno)
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
        case Ok:                  return @"No error";
        case Cancelled:           return @"Operation was cancelled";
        case NotSupported:        return @"Operation is not supported";
        case InvalidCall:         return @"Invalid call";
        case GenericError:        return @"Generic error";
        case NotFound:            return @"Item not found";
        case UnexpectedEOF:       return @"An unexpected end of file occured";
        case ArclibFileFormat:    return @"Unrecognized or invalid archive file format";
        case ArclibProgError:     return @"Internal archive module error";
        case ArclibMiscError:     return @"Unknown or unclassified archive error";
        case UnRARFailedToOpenArchive: return @"Failed to open RAR archive";
        case UnRARBadData:          return @"Bad RAR data";
        case UnRARBadArchive:       return @"Bad RAR archive";
        case UnRARUnknownFormat:    return @"Unknown RAR format";
        case UnRARMissingPassword:  return @"Missing RAR password";
        case UnRARBadPassword:      return @"Bad RAR password";
        case NetFTPLoginDenied:         return @"The remote server denied to login";
        case NetFTPURLMalformat:        return @"URL malformat";
        case NetFTPServerProblem:       return @"Weird FTP server behaviour";
        case NetFTPCouldntResolveProxy: return @"Couldn't resolve proxy for FTP server";
        case NetFTPCouldntResolveHost:  return @"Couldn't resolve FTP server host";
        case NetFTPCouldntConnect:      return @"Failed to connect to remote FTP server";
        case NetFTPAccessDenied:        return @"Access to remote resource is denied";
        case NetFTPOperationTimeout:    return @"Operation timeout";
        case NetFTPSSLFailure:          return @"FTP+SSL/TLS failure";
    }
    return [NSString stringWithFormat:@"Error code %d", _code];
}

NSError* ToNSError(int _code)
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

}
