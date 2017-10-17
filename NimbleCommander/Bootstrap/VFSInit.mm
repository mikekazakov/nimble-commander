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
    VFSFactory::Instance().RegisterVFS(           VFSPSHost::Meta() );
    VFSFactory::Instance().RegisterVFS(       vfs::SFTPHost::Meta() );
    VFSFactory::Instance().RegisterVFS(       VFSNetFTPHost::Meta() );
    VFSFactory::Instance().RegisterVFS(   VFSNetDropboxHost::Meta() );
    VFSFactory::Instance().RegisterVFS(      VFSArchiveHost::Meta() );
    VFSFactory::Instance().RegisterVFS( VFSArchiveUnRARHost::Meta() );
    VFSFactory::Instance().RegisterVFS(        VFSXAttrHost::Meta() );
    VFSFactory::Instance().RegisterVFS(     vfs::WebDAVHost::Meta() );
}

}
