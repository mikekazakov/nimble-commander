#include "NetworkConnectionIconProvider.h"
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <VFS/NetDropbox.h>
#include <VFS/NetWebDAV.h>

static const auto g_16px = NSMakeSize(16, 16);

static NSImage *Generic()
{
    const auto image = []{
        auto m = [NSImage imageNamed:@"GenericNetworkServer16px"];
        m.size = g_16px;
        return m;
    }();
    return image;
}

static NSImage *Share()
{
    const auto image = []{
        auto m = [NSImage imageNamed:@"GenericLANServer16px"];
        m.size = g_16px;
        return m;
    }();
    return image;
}

static NSImage *Dropbox()
{
    const auto image = []{
        auto m = [NSImage imageNamed:@"GenericDropboxStorage16px"];
        m.size = g_16px;
        return m;
    }();
    return image;
}

NSImage *NetworkConnectionIconProvider::
    Icon16px(const NetworkConnectionsManager::Connection &_connection) const
{
    if( _connection.IsType<NetworkConnectionsManager::LANShare>() )
        return Share();
    if( _connection.IsType<NetworkConnectionsManager::Dropbox>() )
        return Dropbox();
    
    return Generic();
}

NSImage *NetworkConnectionIconProvider::Icon16px(const VFSInstanceManager::Promise &_promise) const
{
    const auto tag = _promise.tag();
    
    if( tag == nc::vfs::DropboxHost::UniqueTag )
        return Dropbox();
    
    if( tag == nc::vfs::FTPHost::UniqueTag ||
        tag == nc::vfs::SFTPHost::UniqueTag ||
        tag == nc::vfs::WebDAVHost::UniqueTag )
        return Generic();
    
    return nil;
}
