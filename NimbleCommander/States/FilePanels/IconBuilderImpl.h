#pragma once

#include "IconBuilder.h"
#include <Utility/QLThumbnailsCache.h>
#include <Utility/WorkspaceIconsCache.h>
#include <Utility/WorkspaceExtensionIconsCache.h>
#include <NimbleCommander/Core/Caches/QLVFSThumbnailsCache.h>

namespace nc::panel {

class IconBuilderImpl : public IconBuilder
{
public:        
    IconBuilderImpl
    (const std::shared_ptr<utility::QLThumbnailsCache> &_ql_cache,
     const std::shared_ptr<utility::WorkspaceIconsCache> &_workspace_icons_cache,
     const std::shared_ptr<utility::WorkspaceExtensionIconsCache> &_extension_icons_cache,
     const std::shared_ptr<utility::QLVFSThumbnailsCache> &_vfs_thumbnails_cache,
     long _max_filesize_for_thumbnails_on_native_fs = 256*1024*1024, 
     long _max_filesize_for_thumbnails_on_vfs = 1*1024*1024    
     );
    ~IconBuilderImpl();
    
    LookupResult LookupExistingIcon( const VFSListingItem &_item, int _icon_px_size ) override;    
    
    BuildResult BuildRealIcon(const VFSListingItem &_item,
                              int _icon_px_size,
                              const CancelChecker &_cancel_checker) override;
    
private:
    NSImage *GetGenericIcon( const VFSListingItem &_item ) const;    
    bool ShouldTryProducingQLThumbnailOnNativeFS(const VFSListingItem &_item) const;
    bool ShouldTryProducingQLThumbnailOnVFS(const VFSListingItem &_item) const; 
    bool ShouldTryProducingBundleIconOnVFS(const VFSListingItem &_item) const; 
    
    std::shared_ptr<utility::QLThumbnailsCache> m_QLThumbnailsCache;
    std::shared_ptr<utility::WorkspaceIconsCache> m_WorkspaceIconsCache;
    std::shared_ptr<utility::WorkspaceExtensionIconsCache> m_ExtensionIconsCache;
    std::shared_ptr<utility::QLVFSThumbnailsCache> m_VFSThumbnailsCache;    
    long m_MaxFilesizeForThumbnailsOnNativeFS = 0;
    long m_MaxFilesizeForThumbnailsOnVFS = 0;
};
    
}
