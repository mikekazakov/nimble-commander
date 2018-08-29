// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
@class NSImage;

namespace nc::utility {

class WorkspaceIconsCache
{
public:    
    virtual ~WorkspaceIconsCache() = default;
    
    /**
     * Returns cached Workspace Icon for specified filename without any checking if it is outdated.
     * Caller should call ProduceThumbnail if he wants to get an actual one.
     */
    virtual NSImage *IconIfHas(const std::string &_filename) = 0;

    virtual NSImage *ProduceIcon(const std::string &_filename) = 0;
};

}
