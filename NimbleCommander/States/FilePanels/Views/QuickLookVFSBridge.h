// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS_fwd.h>

namespace nc::panel {
    
class QuickLookVFSBridge
{
public:
    NSURL *FetchItem( const string& _path, VFSHost &_host );
};

}
