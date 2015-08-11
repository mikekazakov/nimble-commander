//
//  VFSError.mm
//  Files
//
//  Created by Michael G. Kazakov on 14.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/errno.h>
#import "../3rd_party/libarchive/archive_platform.h"
#import "VFSError.h"
#import "VFSDeclarations.h"

static NSString *const g_Domain = @__FILES_IDENTIFIER__".vfs";

VFSErrorException::VFSErrorException( int _err ) :
    m_Code(_err)
{
    m_Verb = "vfs exception code #"s + to_string(_err);
}

const char* VFSErrorException::what() const noexcept
{
    return m_Verb.c_str();
}

int VFSErrorException::code() const noexcept
{
    return m_Code;
}

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
        case NetSFTPCouldntResolveHost: return @"Couldn't resolve SFTP server host";
        case NetSFTPCouldntConnect:     return @"Failed to connect remote SFTP server";
        case NetSFTPCouldntEstablishSSH:return @"Failed to establish SSH session";
        case NetSFTPCouldntAuthenticatePassword:return @"Authentication by password failed";
        case NetSFTPCouldntAuthenticateKey:return @"Authentication by key failed";
        case NetSFTPCouldntInitSFTP:    return @"Unable to init SFTP session";
        case NetSFTPErrorSSH:           return @"SSH error";
        case NetSFTPEOF:                return @"End of file";
        case NetSFTPNoSuchFile:         return @"No such file";
        case NetSFTPPermissionDenied:   return @"Permission denied";
        case NetSFTPFailure:            return @"General SFTP failure";
        case NetSFTPBadMessage:         return @"Bad message";
        case NetSFTPNoConnection:       return @"No connection";
        case NetSFTPConnectionLost:     return @"Connection lost";
        case NetSFTPOpUnsupported:      return @"Operation unsupported";
        case NetSFTPInvalidHandle:      return @"Invalid handle";
        case NetSFTPNoSuchPath:         return @"No such path";
        case NetSFTPFileAlreadyExists:  return @"File already exists";
        case NetSFTPWriteProtect:       return @"Write protect";
        case NetSFTPNoMedia:            return @"No media";
        case NetSFTPNoSpaceOnFilesystem:return @"No space on filesystem";
        case NetSFTPQuotaExceeded:      return @"Quota exceeded";
        case NetSFTPUnknownPrincipal:   return @"Unknown principal";
        case NetSFTPLockConflict:       return @"Lock conflict";
        case NetSFTPDirNotEmpty:        return @"Directory not empty";
        case NetSFTPNotADir:            return @"Not a directory";
        case NetSFTPInvalidFilename:    return @"Invalid filename";
        case NetSFTPLinkLoop:           return @"Link loop";
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
