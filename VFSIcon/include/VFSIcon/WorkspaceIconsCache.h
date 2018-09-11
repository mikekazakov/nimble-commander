// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
@class NSImage;

namespace nc::vfsicon {

/**
 * All methods are thread-safe.
 */
class WorkspaceIconsCache
{
public:    
    virtual ~WorkspaceIconsCache() = default;
    
    /**
     * Returns cached Workspace Icon for specified filename without any checking if it is outdated.
     * Caller should call ProduceThumbnail if he wants to get an actual one.
     */
    virtual NSImage *IconIfHas(const std::string &_file_path) = 0;

    /**
     * Will check if the cache has an appropriate icon for the path.
     * If it does not - will build an icon from scratch.
     * If it has - will check if the file changed and will rebuild the icon only if this is
     * required.
     * Will return nil for files inaccessible with regular rights.
     */
    virtual NSImage *ProduceIcon(const std::string &_file_path) = 0;

};

}
