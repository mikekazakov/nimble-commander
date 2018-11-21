// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/VFS/VFSArchiveProxy.h"
#include "ArcLA/Host.h"
#include "ArcUnRAR/Host.h"

//bool VFSArchiveProxy::CanOpenFileAsArchive(const string &_path,
//                                           shared_ptr<VFSHost> _parent)
//{
//    if(_parent->IsNativeFS() &&
//       VFSArchiveUnRARHost::IsRarArchive(_path.c_str()))
//        return true;
//        
//    // libarchive here
//    assert(0); // not yet implemented
//    
//    return false;
//}

VFSHostPtr VFSArchiveProxy::OpenFileAsArchive(const std::string &_path,
                                              const VFSHostPtr &_parent,
                                              std::function<std::string()> _passwd,
                                              VFSCancelChecker _cancel_checker
                                              )
{
    if(_parent->IsNativeFS() &&
       nc::vfs::UnRARHost::IsRarArchive(_path.c_str()) )
    {
        try {
            auto host = std::make_shared<nc::vfs::UnRARHost>(_path);
            return host;
        } catch (VFSErrorException &e) {
        }
        return nullptr;
    }
    
    try {
        auto archive = std::make_shared<nc::vfs::ArchiveHost>(_path,
                                                              _parent,
                                                              std::nullopt,
                                                              _cancel_checker);
        return archive;
    } catch (VFSErrorException &e) {
        if( e.code() == VFSError::ArclibPasswordRequired && _passwd ) {
            auto passwd = _passwd();
            if( passwd.empty() )
                return nullptr;
            try {
                auto archive = std::make_shared<nc::vfs::ArchiveHost>(_path,
                                                                      _parent,
                                                                      passwd,
                                                                      _cancel_checker);
                return archive;
            } catch (VFSErrorException &e) {
            }
        }
    }
    
    return nullptr;
}
