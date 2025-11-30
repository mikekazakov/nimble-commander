// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NetworkConnectionIconProvider.h"
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <VFS/NetWebDAV.h>
#include <Cocoa/Cocoa.h>

static const auto g_16px = NSMakeSize(16, 16);

static NSImage *Generic()
{
    const auto image = [] {
        auto m = [NSImage imageNamed:@"GenericNetworkServer16px"];
        m.size = g_16px;
        return m;
    }();
    return image;
}

static NSImage *Share()
{
    const auto image = [] {
        auto m = [NSImage imageNamed:@"GenericLANServer16px"];
        m.size = g_16px;
        return m;
    }();
    return image;
}

NSImage *NetworkConnectionIconProvider::Icon16px(const nc::panel::NetworkConnectionsManager::Connection &_connection)
{
    if( _connection.IsType<nc::panel::NetworkConnectionsManager::LANShare>() )
        return Share();

    return Generic();
}

static NSImage *ImageFromTag(const char *_tag)
{
    if( _tag == nc::vfs::FTPHost::UniqueTag || _tag == nc::vfs::SFTPHost::UniqueTag ||
        _tag == nc::vfs::WebDAVHost::UniqueTag )
        return Generic();

    return nil;
}

NSImage *NetworkConnectionIconProvider::Icon16px(const nc::core::VFSInstancePromise &_promise)
{
    return ImageFromTag(_promise.tag());
}

NSImage *NetworkConnectionIconProvider::Icon16px(const VFSHost &_host)
{
    return ImageFromTag(_host.Tag());
}
