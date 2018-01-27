// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
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

static NSImage *ImageFromTag( const char *_tag )
{
    if( _tag == nc::vfs::DropboxHost::UniqueTag )
        return Dropbox();
    
    if( _tag == nc::vfs::FTPHost::UniqueTag ||
        _tag == nc::vfs::SFTPHost::UniqueTag ||
        _tag == nc::vfs::WebDAVHost::UniqueTag )
        return Generic();
    
    return nil;
}

NSImage *NetworkConnectionIconProvider::Icon16px(const nc::core::VFSInstancePromise &_promise) const
{
    return ImageFromTag(_promise.tag());
}

NSImage *NetworkConnectionIconProvider::Icon16px(const VFSHost &_host) const
{
    return ImageFromTag(_host.Tag());
}
