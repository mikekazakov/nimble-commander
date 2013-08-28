//
//  VFSError.h
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

struct VFSError
{
    enum {
        Ok              = 0,
        Cancelled       = -1,
        NotSupported    = -2,
        InvalidCall     = -3,
        NotFound        = -4,
        UnexpectedEOF   = -5,
    };
    
    static int FromErrno(int _errno)
    {
        return -100; // TODO: write me
        
        
    }
};