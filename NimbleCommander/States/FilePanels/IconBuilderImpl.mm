#include "IconBuilderImpl.h"

namespace nc::panel {

IconBuilderImpl::IconBuilderImpl
    (const std::shared_ptr<utility::QLThumbnailsCache> &_ql_cache,
     const std::shared_ptr<utility::WorkspaceIconsCache> &_workspace_icons_cache,
     const std::shared_ptr<utility::WorkspaceExtensionIconsCache> &_extension_icons_cache,
     const std::shared_ptr<utility::QLVFSThumbnailsCache> &_vfs_thumbnails_cache,     
     long _max_filesize_for_thumbnails_on_native_fs, 
     long _max_filesize_for_thumbnails_on_vfs):
    m_QLThumbnailsCache(_ql_cache),
    m_WorkspaceIconsCache(_workspace_icons_cache),
    m_ExtensionIconsCache(_extension_icons_cache),
    m_VFSThumbnailsCache(_vfs_thumbnails_cache),
    m_MaxFilesizeForThumbnailsOnNativeFS(_max_filesize_for_thumbnails_on_native_fs),
    m_MaxFilesizeForThumbnailsOnVFS(_max_filesize_for_thumbnails_on_vfs)
{
}

IconBuilderImpl::~IconBuilderImpl()
{        
}
    
IconBuilder::LookupResult
    IconBuilderImpl::LookupExistingIcon( const VFSListingItem &_item, int _icon_px_size )
{
    assert( _item );
    assert( _icon_px_size > 0 );
    
    LookupResult result;
    
    if( _item.Host()->IsNativeFS() ) {
        const auto path = _item.Path();
        if( auto thumbnail = m_QLThumbnailsCache->ThumbnailIfHas(path, _icon_px_size) ) {
            result.thumbnail = thumbnail;
        }
        else {
            if( auto workspace_icon = m_WorkspaceIconsCache->IconIfHas(path) ) {
                result.filetype = workspace_icon;
            }
            else {
                if( _item.HasExtension() ) {
                    if( auto extension_icon =
                        m_ExtensionIconsCache->IconForExtension( _item.Extension() )){
                        result.filetype = extension_icon;
                    }
                    else {
                        result.generic = GetGenericIcon(_item);
                    }
                }
                else {
                    result.generic = GetGenericIcon(_item);
                }
            }
        } 
    }
    else {
        if( _item.HasExtension() ) {
            if( auto extension_icon =
               m_ExtensionIconsCache->IconForExtension( _item.Extension() )){
                result.filetype = extension_icon;
            }
            else {
                result.generic = GetGenericIcon(_item);
            }
        }
        else {
            result.generic = GetGenericIcon(_item);
        }        
    }
    return result;
}
    
IconBuilder::BuildResult
    IconBuilderImpl::BuildRealIcon(const VFSListingItem &_item,
                                   int _icon_px_size,
                                   const CancelChecker &_cancel_checker)
{
    assert( _item );
    assert( _icon_px_size > 0 );
    
    if( bool(_cancel_checker) && _cancel_checker() )
        return {};
    
    BuildResult result;    
    
    const auto path = _item.Path();    
     if( _item.Host()->IsNativeFS() ) {
        // playing inside a real FS, that can be reached via QL framework
         
        // 1st - try to built a real thumbnail
        if( ShouldTryProducingQLThumbnailOnNativeFS(_item) ) {
            auto file_hint = utility::QLThumbnailsCache::FileStateHint{};
            file_hint.size = _item.Size();
            file_hint.mtime = _item.MTime();
            result.thumbnail = m_QLThumbnailsCache->ProduceThumbnail(path,
                                                                     _icon_px_size,
                                                                     file_hint);
            if( result.thumbnail )
                return result;
        }
        
         if( bool(_cancel_checker) && _cancel_checker() )
             return {};
        
        // 2nd - if we haven't built a real thumbnail - try an extension instead
         result.filetype = m_WorkspaceIconsCache->ProduceIcon( path );
         return result;
     }
     else {
         if( _item.Host()->ShouldProduceThumbnails() == false )
             return {};
         
         // special case for for bundles
         if( ShouldTryProducingBundleIconOnVFS(_item) )
             result.thumbnail = m_VFSThumbnailsCache->ProduceBundleThumbnail(path,
                                                                             *_item.Host(),
                                                                             _icon_px_size);
         
         if( result.thumbnail )
             return result;
         
         if( bool(_cancel_checker) && _cancel_checker() )
             return {};         
         
         // produce QL icon for file
         if( ShouldTryProducingQLThumbnailOnVFS(_item) ) {
             result.thumbnail = m_VFSThumbnailsCache->ProduceFileThumbnail(path,
                                                                           *_item.Host(),
                                                                           _icon_px_size);

             if( result.thumbnail )
                 return result;             
         }
         
         return {};
     }    
}    

NSImage *IconBuilderImpl::GetGenericIcon( const VFSListingItem &_item ) const
{
    return _item.IsDir() ? 
        m_ExtensionIconsCache->GenericFolderIcon() :
        m_ExtensionIconsCache->GenericFileIcon();
}

bool IconBuilderImpl::ShouldTryProducingQLThumbnailOnNativeFS(const VFSListingItem &_item) const    
{
    return _item.IsDir() == false &&
        _item.Size() > 0 &&
        long(_item.Size()) < m_MaxFilesizeForThumbnailsOnNativeFS;
}

bool IconBuilderImpl::ShouldTryProducingQLThumbnailOnVFS(const VFSListingItem &_item) const
{
    return _item.IsDir() == false &&
        _item.Size() > 0 &&
        long(_item.Size()) < m_MaxFilesizeForThumbnailsOnVFS &&
        _item.HasExtension();        
}
 
static bool MightBeBundle(const VFSListingItem &_item)
{
    if( _item.HasExtension() == false )
        return false;
        
    const auto extension = _item.Extension();
    return "app"sv == extension; 
}    

bool IconBuilderImpl::ShouldTryProducingBundleIconOnVFS(const VFSListingItem &_item) const
{ 
    return MightBeBundle(_item); 
}
    
}
