// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>

@class NSImage;

namespace nc::vfsicon {

/**
 * All methods are thread-safe.
 */    
class QLThumbnailsCache
{
public:
    virtual ~QLThumbnailsCache() = default;
    
    /**
     * Returns cached QLThunmbnail for specified filename without any checking if it is outdated.
     * Caller should call ProduceThumbnail if he wants to get an actual one.
     * May return nil.
     */
    virtual NSImage *ThumbnailIfHas(const std::string &_file_path,
                                    int _px_size) = 0;
    
    /**
     * Will check for a presence of a thumbnail for _file_path in cache.
     * If it is, will check if file wasn't changed - in this case just return a thumbnail that we
     * already have.
     * If file was changed or there's no thumbnail for this file - will produce a fresh thumbnail
     * and will return it.
     * May return nil.
     */
    virtual NSImage *ProduceThumbnail(const std::string &_file_path,
                                      int _px_size) = 0;
    
    struct FileStateHint {
        uint64_t    size = 0;
        uint64_t    mtime = 0;
    };
    /**
     * Same as ProduceThumbnail(filename, px_size), but can use additional information available 
     * for caller. It may decreate redundant I/O operations when checking for current file state.
     */
    virtual NSImage *ProduceThumbnail(const std::string &_file_path,
                                      int _px_size,
                                      const FileStateHint& _hint) = 0;
};

}
