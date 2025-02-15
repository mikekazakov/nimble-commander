// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/VFS/VFSArchiveProxy.h"
#include "ArcLA/Host.h"
#include "ArcLARaw/Host.h"

// TODO: move to a namespace

using namespace nc;

VFSHostPtr VFSArchiveProxy::OpenFileAsArchive(const std::string &_path,
                                              const VFSHostPtr &_parent,
                                              [[maybe_unused]] std::function<std::string()> _passwd,
                                              VFSCancelChecker _cancel_checker)
{
    try {
        auto archive = std::make_shared<nc::vfs::ArchiveHost>(_path, _parent, std::nullopt, _cancel_checker);
        return archive;
    } catch( ErrorException &e ) {
        if( e.error().Domain() == VFSError::ErrorDomain && e.error().Code() == VFSError::ArclibPasswordRequired &&
            _passwd ) {
            auto passwd = _passwd();
            if( passwd.empty() )
                return nullptr;
            try {
                auto archive = std::make_shared<nc::vfs::ArchiveHost>(_path, _parent, passwd, _cancel_checker);
                return archive;
            } catch( ErrorException &e ) {
            }
            return nullptr;
        }
    }

    if( nc::vfs::ArchiveRawHost::HasSupportedExtension(_path) ) {
        try {
            auto archive = std::make_shared<nc::vfs::ArchiveRawHost>(_path, _parent, _cancel_checker);
            return archive;
        } catch( ErrorException &e ) {
        }
    }

    return nullptr;
}
