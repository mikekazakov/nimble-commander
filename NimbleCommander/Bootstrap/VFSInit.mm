// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "VFSInit.h"
#include <VFS/Native.h>
#include <VFS/ArcLA.h>
#include <VFS/ArcUnRAR.h>
#include <VFS/PS.h>
#include <VFS/XAttr.h>
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <VFS/NetDropbox.h>
#include <VFS/NetWebDAV.h>

namespace nc::bootstrap {

void RegisterAvailableVFS()
{
    VFSFactory::Instance().RegisterVFS(       VFSNativeHost::Meta() );
    VFSFactory::Instance().RegisterVFS(         vfs::PSHost::Meta() );
    VFSFactory::Instance().RegisterVFS(       vfs::SFTPHost::Meta() );
    VFSFactory::Instance().RegisterVFS(        vfs::FTPHost::Meta() );
    VFSFactory::Instance().RegisterVFS(    vfs::DropboxHost::Meta() );
    VFSFactory::Instance().RegisterVFS(    vfs::ArchiveHost::Meta() );
    VFSFactory::Instance().RegisterVFS(      vfs::UnRARHost::Meta() );
    VFSFactory::Instance().RegisterVFS(      vfs::XAttrHost::Meta() );
    VFSFactory::Instance().RegisterVFS(     vfs::WebDAVHost::Meta() );
}

}
