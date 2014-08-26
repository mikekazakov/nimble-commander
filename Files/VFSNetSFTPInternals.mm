//
//  VFSNetSFTPInternals.mm
//  Files
//
//  Created by Michael G. Kazakov on 25/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "VFSNetSFTPInternals.h"

namespace VFSNetSFTP
{

Connection::~Connection()
{
    // todo: non-blocking ops
    
    if(sftp) {
        libssh2_sftp_shutdown(sftp);
        sftp = nullptr;
    }
    
    if(ssh) {
        libssh2_session_disconnect(ssh, "bye");
        libssh2_session_free(ssh);
        ssh = nullptr;
    }
    
    if(socket >= 0) {
        close(socket);
        socket = -1;
    }
}
    
    
    
    
}