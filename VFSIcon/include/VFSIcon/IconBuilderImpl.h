// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFSIcon/IconBuilder.h>
#include <VFSIcon/QLThumbnailsCache.h>
#include <VFSIcon/WorkspaceIconsCache.h>
#include <VFSIcon/WorkspaceExtensionIconsCache.h>
#include <VFSIcon/QLVFSThumbnailsCache.h>
#include <VFSIcon/VFSBundleIconsCache.h>
#include <VFSIcon/ExtensionsWhitelist.h>

namespace nc::vfsicon {

class IconBuilderImpl : public IconBuilder
{
public:        
    IconBuilderImpl
    (const std::shared_ptr<QLThumbnailsCache> &_ql_cache,
     const std::shared_ptr<WorkspaceIconsCache> &_workspace_icons_cache,
     const std::shared_ptr<WorkspaceExtensionIconsCache> &_extension_icons_cache,
     const std::shared_ptr<QLVFSThumbnailsCache> &_vfs_thumbnails_cache,
     const std::shared_ptr<VFSBundleIconsCache> &_vfs_bundle_icons_cache,
     const std::shared_ptr<ExtensionsWhitelist> &_extensions_whitelist,
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
    
    std::shared_ptr<QLThumbnailsCache> m_QLThumbnailsCache;
    std::shared_ptr<WorkspaceIconsCache> m_WorkspaceIconsCache;
    std::shared_ptr<WorkspaceExtensionIconsCache> m_ExtensionIconsCache;
    std::shared_ptr<QLVFSThumbnailsCache> m_VFSThumbnailsCache;
    std::shared_ptr<VFSBundleIconsCache> m_VFSBundleIconsCache;    
    std::shared_ptr<ExtensionsWhitelist> m_ExtensionsWhitelist;
    long m_MaxFilesizeForThumbnailsOnNativeFS = 0;
    long m_MaxFilesizeForThumbnailsOnVFS = 0;
};
    
}
