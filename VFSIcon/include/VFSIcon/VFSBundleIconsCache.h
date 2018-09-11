// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <Cocoa/Cocoa.h>

namespace nc::vfsicon {
    
class VFSBundleIconsCache
{
public:
    virtual ~VFSBundleIconsCache() = default;
    
    virtual NSImage *IconIfHas(const std::string &_file_path, VFSHost &_host) = 0;
    
    virtual NSImage *ProduceIcon(const std::string &_file_path, VFSHost &_host) = 0;    
};
    
}
