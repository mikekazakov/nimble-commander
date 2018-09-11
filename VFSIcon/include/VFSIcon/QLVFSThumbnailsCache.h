// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

namespace nc::vfsicon {
    
class QLVFSThumbnailsCache
{
public:
    virtual ~QLVFSThumbnailsCache() = default;
    
    virtual NSImage *ThumbnailIfHas(const std::string &_file_path,
                                    VFSHost &_host,
                                    int _px_size) = 0;
    
    virtual NSImage *ProduceThumbnail(const std::string &_file_path,
                                      VFSHost &_host,
                                      int _px_size) = 0;    
};

}
