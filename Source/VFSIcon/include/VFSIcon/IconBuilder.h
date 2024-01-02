// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>

namespace nc::vfsicon {

/**
 * All methods are thread-safe.
 */
class IconBuilder
{
public:
    virtual ~IconBuilder() = default;
  
    struct LookupResult {
        NSImage *thumbnail = nil; // the best - thumbnail generated from file's content
        NSImage *filetype = nil;  // icon generated from file type or taken from a bundle
        NSImage *generic = nil;   // just folder or document icon
    };
    /**
     * Thumbnail has priority over filetype, and filetype has priority over generic icon.
     * If an icon with higher priority is not nil, others might be skipped during lookup.
     * Lookup does a shallow operation, which generally does not involve any I/O,
     * and should be relatively fast.
     * The calling code should not rely on .size attribute of produced images. To adjust it, make 
     * a copy and change its size.
     */
    virtual LookupResult LookupExistingIcon(const VFSListingItem &_item,
                                            int _icon_px_size) = 0;
    
    struct BuildResult {
        NSImage *thumbnail = nil; // the best - thumbnail generated from file's content
        NSImage *filetype = nil;  // icon generated from file type or taken from a bundle        
    };
    using CancelChecker = std::function<bool()>;
    /**
     * Thumbnail has priority over filetype.
     * If a thumbnail is not nil, filetype lookup might be skipped during.
     * Building an icon can be a timely operation, thus it's assumed to be called from background
     * threads.
     * If _cancel_checker is provided it can be executed during the build process. If it returns
     * 'true' the process will be stopped and function will return a default value.
     * The calling code should not rely on .size attribute of produced images. To adjust it, make 
     * a copy and change its size.     
     */
    virtual BuildResult BuildRealIcon(const VFSListingItem &_item,
                                      int _icon_px_size,
                                      const CancelChecker &_cancel_checker = CancelChecker{}) = 0;
};

}
