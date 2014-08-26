//
//  VFSNetSFTPInternals.h
//  Files
//
//  Created by Michael G. Kazakov on 25/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include "3rd_party/built/include/libssh2.h"
#include "3rd_party/built/include/libssh2_sftp.h"


namespace VFSNetSFTP
{


    struct Connection
    {
        ~Connection();
        
        
        
        LIBSSH2_SFTP       *sftp   = nullptr;
        LIBSSH2_SESSION    *ssh    = nullptr;
        int                 socket = -1;
    };
    
    
    
    
    
    
    
}
