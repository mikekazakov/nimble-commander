#include "IconBuilderImpl.h"



// TODO: remove this crap:
#include <Quartz/Quartz.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/dirent.h>
#include <Habanero/CommonPaths.h>
#include <NimbleCommander/Core/Caches/QLVFSThumbnailsCache.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <Utility/BriefOnDiskStorageImpl.h>


















namespace nc::panel {

IconBuilderImpl::IconBuilderImpl
    (const std::shared_ptr<utility::QLThumbnailsCache> &_ql_cache,
     const std::shared_ptr<utility::WorkspaceIconsCache> &_workspace_icons_cache,
     const std::shared_ptr<utility::WorkspaceExtensionIconsCache> &_extension_icons_cache,
     long _max_filesize_for_thumbnails_on_native_fs, 
     long _max_filesize_for_thumbnails_on_vfs):
    m_QLThumbnailsCache(_ql_cache),
    m_WorkspaceIconsCache(_workspace_icons_cache),
    m_ExtensionIconsCache(_extension_icons_cache),
    m_MaxFilesizeForThumbnailsOnNativeFS(_max_filesize_for_thumbnails_on_native_fs),
    m_MaxFilesizeForThumbnailsOnVFS(_max_filesize_for_thumbnails_on_vfs)
{
}

IconBuilder::LookupResult
    IconBuilderImpl::LookupExistingIcon( const VFSListingItem &_item, int _icon_px_size )
{
    if( bool(_item) == false || _icon_px_size <= 0 )
        return {};
        
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
    
    
    

static NSImage *ProduceThumbnailForTempFile(const string &_path, CGSize _px_size)
{

    CFURLRef url = CFURLCreateFromFileSystemRepresentation(nullptr,
                                                           (const UInt8 *)_path.c_str(),
                                                           _path.length(),
                                                           false);
    static void *keys[] = {(void*)kQLThumbnailOptionIconModeKey};
    static void *values[] = {(void*)kCFBooleanTrue};
    static CFDictionaryRef dict = CFDictionaryCreate(0,
                                                     (const void**)keys,
                                                     (const void**)values, 1, 0, 0);
    NSImage *result = 0;
    if( CGImageRef thumbnail = QLThumbnailImageCreate(0, url, _px_size, dict) ) {
        result = [[NSImage alloc] initWithCGImage:thumbnail size:_px_size];
        CGImageRelease(thumbnail);
    }
    CFRelease(url);        
    return result;
}
    
static optional<vector<uint8_t>> ReadEntireVFSFile(const string &_path, const VFSHostPtr &_host)
{
    VFSFilePtr vfs_file;
    
    if( _host->CreateFile(_path.c_str(), vfs_file, 0) < 0 )
        return nullopt;
    
    if( vfs_file->Open(VFSFlags::OF_Read) < 0)
        return nullopt;
    
    return vfs_file->ReadFile(); 
}
    
static NSImage *ProduceThumbnailForVFS(const string &_path,
                                   const string &_ext,
                                   const VFSHostPtr &_host,
                                   CGSize _sz)
{    
    auto data = ReadEntireVFSFile(_path, _host);
    if( data.has_value() == false )
        return nil;
    
    // remove this dependency:
    utility::BriefOnDiskStorageImpl brief_storage(CommonPaths::AppTemporaryDirectory(),
                                                  ActivationManager::BundleID() + ".ico");

    auto placement_result = brief_storage.PlaceWithExtension(data->data(), data->size(), _ext);
    if( placement_result.has_value() == false )
        return nil;
        
    return ProduceThumbnailForTempFile(placement_result->Path(), _sz);
}

static NSImage *ProduceThumbnailForVFS_Cached(const string &_path, const string &_ext, const VFSHostPtr &_host, CGSize _sz)
{
    // for immutable vfs we can cache generated thumbnails for some time
    pair<bool, NSImage *> thumbnail = {false, nil}; // found -> value
    
    if( _host->IsImmutableFS() )
        thumbnail = QLVFSThumbnailsCache::Instance().Get(_path, _host);
    
    if( !thumbnail.first ) {
        thumbnail.second = ProduceThumbnailForVFS(_path, _ext, _host, _sz);
        if( _host->IsImmutableFS() )
            QLVFSThumbnailsCache::Instance().Put(_path, _host, thumbnail.second);
    }
    
    return thumbnail.second;
}

static NSDictionary *ReadDictionaryFromVFSFile(const char *_path, const VFSHostPtr &_host)
{
    VFSFilePtr vfs_file;
    if(_host->CreateFile(_path, vfs_file, 0) < 0)
        return 0;
    if(vfs_file->Open(VFSFlags::OF_Read) < 0)
        return 0;
    NSData *data = vfs_file->ReadFileToNSData();
    vfs_file.reset();
    if(data == 0)
        return 0;
    
    id obj = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:0 error:0];
    return objc_cast<NSDictionary>(obj);
}

static NSImage *ReadImageFromVFSFile(const char *_path, const VFSHostPtr &_host)
{
    VFSFilePtr vfs_file;
    if(_host->CreateFile(_path, vfs_file, 0) < 0)
        return 0;
    if(vfs_file->Open(VFSFlags::OF_Read) < 0)
        return 0;
    NSData *data = vfs_file->ReadFileToNSData();
    vfs_file.reset();
    if(data == 0)
        return 0;
    
    return [[NSImage alloc] initWithData:data];
}

static NSImage *ProduceBundleThumbnailForVFS(const string &_path, const VFSHostPtr &_host)
{
    NSDictionary *plist = ReadDictionaryFromVFSFile((path(_path) / "Contents/Info.plist").c_str(), _host);
    if(!plist)
        return 0;
    
    auto icon_str = objc_cast<NSString>([plist objectForKey:@"CFBundleIconFile"]);
    if(!icon_str)
        return nil;
    if(!icon_str.fileSystemRepresentation)
        return nil;
    
    path img_path = path(_path) / "Contents/Resources/" / icon_str.fileSystemRepresentation;
    NSImage *image = ReadImageFromVFSFile(img_path.c_str(), _host);
    if(!image)
        return 0;
    
    return image;
}

static NSImage *ProduceBundleThumbnailForVFS_Cached(const string &_path, const VFSHostPtr &_host)
{
    // for immutable vfs we can cache generated thumbnails for some time
    pair<bool, NSImage*> thumbnail = {false, nil}; // found -> value
    
    if( _host->IsImmutableFS() )
        thumbnail = QLVFSThumbnailsCache::Instance().Get(_path, _host);
    
    if( !thumbnail.first ) {
        thumbnail.second = ProduceBundleThumbnailForVFS(_path, _host);
        if( _host->IsImmutableFS() )
            QLVFSThumbnailsCache::Instance().Put(_path, _host, thumbnail.second);
    }
    
    return thumbnail.second;
}
    
IconBuilder::BuildResult
    IconBuilderImpl::BuildRealIcon(const VFSListingItem &_item,
                                   int _icon_px_size,
                                   const CancelChecker &_cancel_checker)
{
    if( bool(_item) == false || _icon_px_size <= 0 )
        return {};    
    
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
            result.thumbnail = m_QLThumbnailsCache->ProduceThumbnail(path, _icon_px_size, file_hint);
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
         // special case for for bundles
         if(_item.HasExtension() &&
            _item.Extension() == "app"s &&
            _item.Host()->ShouldProduceThumbnails() )
             result.thumbnail = ProduceBundleThumbnailForVFS_Cached( path, _item.Host() );
         
         if( result.thumbnail )
             return result;
         
         if( bool(_cancel_checker) && _cancel_checker() )
             return {};         
         
         // produce QL icon for file
         if( ShouldTryProducingQLThumbnailOnVFS(_item) ) {
             const auto sz = NSMakeSize(_icon_px_size, _icon_px_size);
             result.thumbnail = ProduceThumbnailForVFS_Cached(path,
                                                              _item.Extension(),
                                                              _item.Host(),
                                                              sz);
             if( result.thumbnail )
                 return result;             
         }
         
         if( bool(_cancel_checker) && _cancel_checker() )
             return {};         
         
         // produce extension icon for file
         if( _item.HasExtension() )
             result.filetype = m_ExtensionIconsCache->IconForExtension(_item.Extension());
         return result;         
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
        _item.Host()->ShouldProduceThumbnails() &&
        _item.HasExtension();        
}
    
}

