#pragma once

#include <libssh2.h>
#include "OSType.h"

namespace nc::vfs::sftp {

class OSDetector
{
public:
    OSDetector( LIBSSH2_SESSION *_session );

    OSType Detect();

private:
    LIBSSH2_SESSION *m_Session;
};

}
