#include "VFSNetSFTPOSDetector.h"

static const auto g_Linux = "Linux";
static const auto g_MacOSX = "Darwin";
static const auto g_DragonFlyBSD = "DragonFly";
static const auto g_FreeBSD = "FreeBSD";
static const auto g_OpenBSD = "OpenBSD";
static const auto g_NetBSD = "NetBSD";



VFSNetSFTPOSDetector::VFSNetSFTPOSDetector( LIBSSH2_SESSION *_session ):
    m_Session(_session)
{
}

VFSNetSFTPOSType VFSNetSFTPOSDetector::Detect()
{
    LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(m_Session);
    if( channel == nullptr )
        return VFSNetSFTPOSType::Unknown;

    int rc = libssh2_channel_exec(channel, "uname -s");
    if( rc < 0 ) {
        libssh2_channel_close(channel);
        libssh2_channel_free(channel);
        return VFSNetSFTPOSType::Unknown;
    }

    char buffer[512];
    rc = (int)libssh2_channel_read( channel, buffer, sizeof(buffer) );
    libssh2_channel_close(channel);
    libssh2_channel_free(channel);

    if( rc <= 0 )
        return VFSNetSFTPOSType::Unknown;
    buffer[rc - 1] = 0;

    const auto eq = [&]( const char *s ) { return strcmp(buffer, s) == 0; };
    if( eq(g_Linux) )
        return VFSNetSFTPOSType::Linux;
    if( eq(g_MacOSX) )
        return VFSNetSFTPOSType::MacOSX;
    if( eq(g_DragonFlyBSD) || eq(g_FreeBSD) || eq(g_OpenBSD) || eq(g_NetBSD) )
        return VFSNetSFTPOSType::xBSD;

    return VFSNetSFTPOSType::Unknown;
}
