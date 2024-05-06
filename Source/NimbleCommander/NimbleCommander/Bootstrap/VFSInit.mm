// Copyright (C) 2017-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "VFSInit.h"
#include <VFS/Native.h>
#include <VFS/ArcLA.h>
#include <VFS/ArcLARaw.h>
#include <VFS/PS.h>
#include <VFS/XAttr.h>
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <VFS/NetDropbox.h>
#include <VFS/NetWebDAV.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>

namespace nc::bootstrap {

void RegisterAvailableVFS()
{
    auto native_meta = VFSNativeHost::Meta();
    native_meta.SpawnWithConfig = [](const VFSHostPtr &, const VFSConfiguration &, VFSCancelChecker) {
        return NCAppDelegate.me.nativeHostPtr;
    };

    VFSFactory::Instance().RegisterVFS(std::move(native_meta));
    VFSFactory::Instance().RegisterVFS(vfs::PSHost::Meta());
    VFSFactory::Instance().RegisterVFS(vfs::SFTPHost::Meta());
    VFSFactory::Instance().RegisterVFS(vfs::FTPHost::Meta());
    VFSFactory::Instance().RegisterVFS(vfs::DropboxHost::Meta());
    VFSFactory::Instance().RegisterVFS(vfs::ArchiveHost::Meta());
    VFSFactory::Instance().RegisterVFS(vfs::ArchiveRawHost::Meta());
    VFSFactory::Instance().RegisterVFS(vfs::XAttrHost::Meta());
    VFSFactory::Instance().RegisterVFS(vfs::WebDAVHost::Meta());
}

} // namespace nc::bootstrap
