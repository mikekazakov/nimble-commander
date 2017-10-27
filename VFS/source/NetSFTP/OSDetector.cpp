// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "OSDetector.h"

namespace nc::vfs::sftp {

static const auto g_Linux = "Linux";
static const auto g_MacOSX = "Darwin";
static const auto g_DragonFlyBSD = "DragonFly";
static const auto g_FreeBSD = "FreeBSD";
static const auto g_OpenBSD = "OpenBSD";
static const auto g_NetBSD = "NetBSD";

OSDetector::OSDetector( LIBSSH2_SESSION *_session ):
    m_Session(_session)
{
}

OSType OSDetector::Detect()
{
    LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(m_Session);
    if( channel == nullptr )
        return OSType::Unknown;

    int rc = libssh2_channel_exec(channel, "uname -s");
    if( rc < 0 ) {
        libssh2_channel_close(channel);
        libssh2_channel_free(channel);
        return OSType::Unknown;
    }

    char buffer[512];
    rc = (int)libssh2_channel_read( channel, buffer, sizeof(buffer) );
    libssh2_channel_close(channel);
    libssh2_channel_free(channel);

    if( rc <= 0 )
        return OSType::Unknown;
    buffer[rc - 1] = 0;

    const auto eq = [&]( const char *s ) { return strcmp(buffer, s) == 0; };
    if( eq(g_Linux) )
        return OSType::Linux;
    if( eq(g_MacOSX) )
        return OSType::MacOSX;
    if( eq(g_DragonFlyBSD) || eq(g_FreeBSD) || eq(g_OpenBSD) || eq(g_NetBSD) )
        return OSType::xBSD;

    return OSType::Unknown;
}

}
