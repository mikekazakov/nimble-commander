#pragma once

#include <libssh2.h>
#include "VFSNetSFTPOSType.h"

class VFSNetSFTPOSDetector
{
public:
    VFSNetSFTPOSDetector( LIBSSH2_SESSION *_session );

    VFSNetSFTPOSType Detect();

private:
    LIBSSH2_SESSION *m_Session;
};

