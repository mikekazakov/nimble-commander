//
//  VFSArchiveProxy.cpp
//  Files
//
//  Created by Michael G. Kazakov on 09.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "VFSArchiveProxy.h"
#include "ArcLA/VFSArchiveHost.h"
#include "ArcUnRAR/VFSArchiveUnRARHost.h"

bool VFSArchiveProxy::CanOpenFileAsArchive(const string &_path,
                                           shared_ptr<VFSHost> _parent)
{
    if(_parent->IsNativeFS() &&
       VFSArchiveUnRARHost::IsRarArchive(_path.c_str()))
        return true;
        
    // libarchive here
    assert(0); // not yet implemented
    
    return false;
}

shared_ptr<VFSHost> VFSArchiveProxy::OpenFileAsArchive(const string &_path,
                                                       shared_ptr<VFSHost> _parent
                                                       )
{
    if(_parent->IsNativeFS() &&
       VFSArchiveUnRARHost::IsRarArchive(_path.c_str()) )
    {
        try {
            auto host = make_shared<VFSArchiveUnRARHost>(_path);
            return host;
        } catch (VFSErrorException &e) {
        }
        return nullptr;
    }
    
    try {
        auto archive = make_shared<VFSArchiveHost>(_path, _parent);
        return archive;
    } catch (VFSErrorException &e) {
    }
    
    return nullptr;
}
