//
//  VFSArchiveProxy.cpp
//  Files
//
//  Created by Michael G. Kazakov on 09.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "VFSArchiveProxy.h"
#include "VFSArchiveHost.h"
#include "VFSArchiveUnRARHost.h"

bool VFSArchiveProxy::CanOpenFileAsArchive(const char *_path,
                                           shared_ptr<VFSHost> _parent)
{
    if(_parent->IsNativeFS() &&
       VFSArchiveUnRARHost::IsRarArchive(_path))
        return true;
        
    // libarchive here
    assert(0); // not yet implemented
    
    return false;
}

shared_ptr<VFSHost> VFSArchiveProxy::OpenFileAsArchive(const char *_path,
                                                       shared_ptr<VFSHost> _parent
                                                       )
{
    if(_parent->IsNativeFS() &&
       VFSArchiveUnRARHost::IsRarArchive(_path) )
    {
        shared_ptr<VFSArchiveUnRARHost> host = make_shared<VFSArchiveUnRARHost>(_path);
        if(host->Open() == 0)
            return host;
        
        return nullptr;
    }
    
    auto archive = make_shared<VFSArchiveHost>(_path, _parent);
    if(archive->Open() >= 0)
        return archive;
    
    return nullptr;
}
