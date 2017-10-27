// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.

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
        ArclibPasswordRequired = -2003, // Password needed.
        
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
        NetSFTPCouldntAuthenticatePassword  = -4003,
        NetSFTPCouldntAuthenticateKey       = -4004,
        NetSFTPCouldntInitSFTP      = -4005,
        NetSFTPErrorSSH             = -4006,
        NetSFTPEOF                  = -4007,
        NetSFTPNoSuchFile           = -4008,
        NetSFTPPermissionDenied     = -4009,
        NetSFTPFailure              = -4010,
        NetSFTPBadMessage           = -4011,
        NetSFTPNoConnection         = -4012,
        NetSFTPConnectionLost       = -4013,
        NetSFTPOpUnsupported        = -4014,
        NetSFTPInvalidHandle        = -4015,
        NetSFTPNoSuchPath           = -4016,
        NetSFTPFileAlreadyExists    = -4017,
        NetSFTPWriteProtect         = -4018,
        NetSFTPNoMedia              = -4019,
        NetSFTPNoSpaceOnFilesystem  = -4020,
        NetSFTPQuotaExceeded        = -4021,
        NetSFTPUnknownPrincipal     = -4022,
        NetSFTPLockConflict         = -4023,
        NetSFTPDirNotEmpty          = -4024,
        NetSFTPNotADir              = -4025,
        NetSFTPInvalidFilename      = -4026,
        NetSFTPLinkLoop             = -4027,
        NetSFTPCouldntReadKey       = -4028,
    };
    
    int FromErrno(int _errno);
    int FromErrno();
    int FromLibarchive(int _errno);
    int FromCFNetwork(int _errno);
    
#ifdef __OBJC__
    NSError* ToNSError(int _code);
    int FromNSError(NSError* _err);
#endif
};
