// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
@class NSImage;

namespace nc::vfsicon {
    
/**
 * All methods are thread-safe.
 */
class WorkspaceExtensionIconsCache
{
public:
    virtual ~WorkspaceExtensionIconsCache() = default;
    
    /**
     * Returns an icon for the extension if the cache already contains it.
     * Otherwise returns nil.
     * Can return nil if the cache wasn't able to produce a corresponding image previously. 
     */
    virtual NSImage *CachedIconForExtension( const std::string& _extension ) const = 0;
    
    /**
     * Checks whether the cache already contains an icon for the extension.
     * If it does - returns it.
     * Otherwise tries to produce a corresponding image.
     * Can return nil.
     */
    virtual NSImage *IconForExtension( const std::string& _extension ) = 0;    
    
    virtual NSImage *GenericFileIcon() const = 0;
    
    virtual NSImage *GenericFolderIcon() const = 0;
};
    
}
