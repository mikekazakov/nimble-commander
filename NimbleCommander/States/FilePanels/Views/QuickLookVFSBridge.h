// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS_fwd.h>

namespace nc::utility {
    class TemporaryFileStorage;
}

namespace nc::panel {
    
class QuickLookVFSBridge
{
public:
    QuickLookVFSBridge(nc::utility::TemporaryFileStorage &_storage,
                       uint64_t _max_size = 64*1024*1024 );
    NSURL *FetchItem( const std::string& _path, VFSHost &_host );
private:
    nc::utility::TemporaryFileStorage &m_TempStorage;
    uint64_t m_MaxSize;
};

}
