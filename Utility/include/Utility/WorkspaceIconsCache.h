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
    virtual NSImage *IconIfHas(const std::string &_file_path) = 0;

    virtual NSImage *ProduceIcon(const std::string &_file_path) = 0;
    
    struct FileStateHint {
        uint64_t    size = 0;
        uint64_t    mtime = 0;
        mode_t      mode = 0;
    };
    virtual NSImage *ProduceIcon(const std::string &_file_path,
                                 const FileStateHint &_state_hint) = 0;
};

}
