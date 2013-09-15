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

struct VFSError
{
    enum {
        // general error codes
        Ok              = 0,        // operation was succesful
        Cancelled       = -1,       // operation was canceled by user with cancel-callback
        NotSupported    = -2,       // call not supported by current object
        InvalidCall     = -3,       // object state is invalid for such call
        GenericError    = -4,       // generic(unknown) error has occured
        
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
    };
    
    static int FromErrno(int _errno);
    static int FromLibarchive(int _errno);

#ifdef __OBJC__
    static NSError* ToNSError(int _code);
#endif
};


