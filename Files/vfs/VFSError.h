 //
//  VFSError.h
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#ifdef __OBJC__
@class NSError;
#endif

namespace VFSError
{
    enum {
        // general error codes
        Ok              = 0,        // operation was succesful
        Cancelled       = -1,       // operation was canceled by user with cancel-callback
        NotSupported    = -2,       // call not supported by current object
        InvalidCall     = -3,       // object state is invalid for such call
        GenericError    = -4,       // generic(unknown) error has occured
        SmallBuffer     = -5,       // Buffer passed to VFS is too small to accomplish operation
        
        // specific error codes
        NotFound        = -100,     // requested item was not found
        UnexpectedEOF   = -101,     // an unexpected end of file has occured

        // UNIX error codes convert:
        // -1001 - error code
        // example: EIO: -1001 - 5 = -1006
        

        // Libarchive error codes convert:
        ArclibFileFormat    = -2000, // Unrecognized or invalid file format.
        ArclibProgError     = -2001, // Illegal usage of the library.
        ArclibMiscError     = -2002, // Unknown or unclassified error.
        
        // UnRAR error codes convert:
        UnRARFailedToOpenArchive = -2100,
        UnRARBadData             = -2101,
        UnRARBadArchive          = -2102,
        UnRARUnknownFormat       = -2103,
        UnRARMissingPassword     = -2104,
        UnRARBadPassword         = -2105,
        
        // Net FTP error codes:
        NetFTPLoginDenied           = -3000,
        NetFTPURLMalformat          = -3001,
        NetFTPServerProblem         = -3002,
        NetFTPCouldntResolveProxy   = -3003,
        NetFTPCouldntResolveHost    = -3004,
        NetFTPCouldntConnect        = -3005,
        NetFTPAccessDenied          = -3006,
        NetFTPOperationTimeout      = -3007,
        NetFTPSSLFailure            = -3008,
        
        // Net SFTP error codes:
        NetSFTPCouldntResolveHost   = -4000,
        NetSFTPCouldntConnect       = -4001,
        NetSFTPCouldntEstablishSSH  = -4002,
        NetSFTPCouldntAuthenticate  = -4003,
        NetSFTPCouldntInitSFTP      = -4004,
        NetSFTPErrorSSH             = -4005,
        NetSFTPEOF                  = -4006,
        NetSFTPNoSuchFile           = -4007,
        NetSFTPPermissionDenied     = -4008,
        NetSFTPFailure              = -4009,
        NetSFTPBadMessage           = -4010,
        NetSFTPNoConnection         = -4011,
        NetSFTPConnectionLost       = -4012,
        NetSFTPOpUnsupported        = -4013,
        NetSFTPInvalidHandle        = -4014,
        NetSFTPNoSuchPath           = -4015,
        NetSFTPFileAlreadyExists    = -4016,
        NetSFTPWriteProtect         = -4017,
        NetSFTPNoMedia              = -4018,
        NetSFTPNoSpaceOnFilesystem  = -4019,
        NetSFTPQuotaExceeded        = -4020,
        NetSFTPUnknownPrincipal     = -4021,
        NetSFTPLockConflict         = -4022,
        NetSFTPDirNotEmpty          = -4023,
        NetSFTPNotADir              = -4024,
        NetSFTPInvalidFilename      = -4025,
        NetSFTPLinkLoop             = -4026,
    };
    
    int FromErrno(int _errno);
    inline int FromErrno() { return FromErrno(errno); }
    int FromLibarchive(int _errno);

#ifdef __OBJC__
    NSError* ToNSError(int _code);
#endif
};
