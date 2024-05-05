// Copyright (C) 2018-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/IconBuilderImpl.h>
#include <VFSIcon/Log.h>
#include <Utility/ObjCpp.h>

namespace nc::vfsicon {

IconBuilderImpl::IconBuilderImpl(const std::shared_ptr<QLThumbnailsCache> &_ql_cache,
                                 const std::shared_ptr<WorkspaceIconsCache> &_workspace_icons_cache,
                                 const std::shared_ptr<WorkspaceExtensionIconsCache> &_extension_icons_cache,
                                 const std::shared_ptr<QLVFSThumbnailsCache> &_vfs_thumbnails_cache,
                                 const std::shared_ptr<VFSBundleIconsCache> &_vfs_bundle_icons_cache,
                                 const std::shared_ptr<ExtensionsWhitelist> &_extensions_whitelist,
                                 long _max_filesize_for_thumbnails_on_native_fs,
                                 long _max_filesize_for_thumbnails_on_vfs)
    : m_QLThumbnailsCache(_ql_cache), m_WorkspaceIconsCache(_workspace_icons_cache),
      m_ExtensionIconsCache(_extension_icons_cache), m_VFSThumbnailsCache(_vfs_thumbnails_cache),
      m_VFSBundleIconsCache(_vfs_bundle_icons_cache), m_ExtensionsWhitelist(_extensions_whitelist),
      m_MaxFilesizeForThumbnailsOnNativeFS(_max_filesize_for_thumbnails_on_native_fs),
      m_MaxFilesizeForThumbnailsOnVFS(_max_filesize_for_thumbnails_on_vfs)
{
}

IconBuilderImpl::~IconBuilderImpl() = default;

IconBuilder::LookupResult IconBuilderImpl::LookupExistingIcon(const VFSListingItem &_item, int _icon_px_size)
{
    if( bool(_item) == false || _icon_px_size <= 0 ) {
        Log::Warn(SPDLOC, "LookupExistingIcon(): invalid lookup request");
        return {};
    }

    Log::Trace(SPDLOC,
               "LookupExistingIcon(): looking up at '{}' for '{}', vfs: '{}'",
               _item.Directory(),
               _item.Filename(),
               _item.Host()->JunctionPath());

    LookupResult result;

    if( _item.Host()->IsNativeFS() ) {
        const auto path = _item.Path();

        result.thumbnail = m_QLThumbnailsCache->ThumbnailIfHas(path, _icon_px_size);
        if( result.thumbnail ) {
            Log::Debug(SPDLOC, "got a thumbnail for '{}'", path);
            return result;
        }

        result.filetype = m_WorkspaceIconsCache->IconIfHas(path);
        if( result.filetype ) {
            Log::Debug(SPDLOC, "got a workspace icon for '{}'", path);
            return result;
        }
    }
    else {
        if( _item.Host()->ShouldProduceThumbnails() ) {
            if( ShouldTryProducingBundleIconOnVFS(_item) ) {
                result.thumbnail = m_VFSBundleIconsCache->IconIfHas(_item.Path(), *_item.Host());
                if( result.thumbnail )
                    return result;
            }
            if( ShouldTryProducingQLThumbnailOnNativeFS(_item) ) {
                result.thumbnail = m_VFSThumbnailsCache->ThumbnailIfHas(_item.Path(), *_item.Host(), _icon_px_size);
                if( result.thumbnail )
                    return result;
            }
        }
    }

    if( _item.HasExtension() ) {
        result.filetype = m_ExtensionIconsCache->IconForExtension(_item.Extension());
        if( result.filetype ) {
            Log::Debug(SPDLOC, "got a filetype icon for '{}'", _item.Filename());
            return result;
        }
    }

    Log::Debug(SPDLOC, "have only a generic icon for '{}'", _item.Filename());
    result.generic = GetGenericIcon(_item);
    return result;
}

IconBuilder::BuildResult
IconBuilderImpl::BuildRealIcon(const VFSListingItem &_item, int _icon_px_size, const CancelChecker &_cancel_checker)
{
    if( bool(_item) == false || _icon_px_size <= 0 ) {
        Log::Warn(SPDLOC, "BuildRealIcon(): invalid lookup request");
        return {};
    }

    Log::Trace(SPDLOC,
               "BuildRealIcon(): building for at '{}' for '{}', vfs: '{}'",
               _item.Directory(),
               _item.Filename(),
               _item.Host()->JunctionPath());

    if( bool(_cancel_checker) && _cancel_checker() )
        return {};

    BuildResult result;

    const auto path = _item.Path();
    if( _item.Host()->IsNativeFS() ) {
        // playing inside a real FS, that can be reached via QL framework

        // 1st - try to built a real thumbnail
        if( ShouldTryProducingQLThumbnailOnNativeFS(_item) ) {
            Log::Debug(SPDLOC, "BuildRealIcon(): building a QL thumbnail for '{}'", _item.Filename());
            auto file_hint = QLThumbnailsCache::FileStateHint{};
            file_hint.size = _item.Size();
            file_hint.mtime = _item.MTime();
            result.thumbnail = m_QLThumbnailsCache->ProduceThumbnail(path, _icon_px_size, file_hint);
            if( result.thumbnail ) {
                Log::Debug(SPDLOC, "BuildRealIcon(): got a QL thumbnail for '{}'", _item.Filename());
                return result;
            }
            else {
                Log::Warn(SPDLOC, "BuildRealIcon(): failed to get a QL thumbnail for '{}'", _item.Filename());
            }
        }

        if( bool(_cancel_checker) && _cancel_checker() )
            return {};

        // 2nd - if we haven't built a real thumbnail - try an extension instead
        result.filetype = m_WorkspaceIconsCache->ProduceIcon(path);
        Log::Debug(SPDLOC,
                   "BuildRealIcon(): got a workspace icon for '{}' = {}",
                   _item.Filename(),
                   objc_bridge_cast<void>(result.filetype));
        return result;
    }
    else {
        if( _item.Host()->ShouldProduceThumbnails() == false )
            return {};

        // special case for for bundles
        if( ShouldTryProducingBundleIconOnVFS(_item) )
            result.thumbnail = m_VFSBundleIconsCache->ProduceIcon(path, *_item.Host());

        if( result.thumbnail )
            return result;

        if( bool(_cancel_checker) && _cancel_checker() )
            return {};

        // produce QL icon for file
        if( ShouldTryProducingQLThumbnailOnVFS(_item) ) {
            result.thumbnail = m_VFSThumbnailsCache->ProduceThumbnail(path, *_item.Host(), _icon_px_size);

            if( result.thumbnail )
                return result;
        }

        return {};
    }
}

NSImage *IconBuilderImpl::GetGenericIcon(const VFSListingItem &_item) const
{
    return _item.IsDir() ? m_ExtensionIconsCache->GenericFolderIcon() : m_ExtensionIconsCache->GenericFileIcon();
}

bool IconBuilderImpl::ShouldTryProducingQLThumbnailOnNativeFS(const VFSListingItem &_item) const
{
    return _item.IsDir() == false && _item.Size() > 0 && long(_item.Size()) < m_MaxFilesizeForThumbnailsOnNativeFS &&
           _item.HasExtension() && m_ExtensionsWhitelist->AllowExtension(_item.Extension());
}

bool IconBuilderImpl::ShouldTryProducingQLThumbnailOnVFS(const VFSListingItem &_item) const
{
    return _item.IsDir() == false && _item.Size() > 0 && long(_item.Size()) < m_MaxFilesizeForThumbnailsOnVFS &&
           _item.HasExtension() && m_ExtensionsWhitelist->AllowExtension(_item.Extension());
}

static bool MightBeBundle(const VFSListingItem &_item)
{
    if( _item.HasExtension() == false )
        return false;

    const auto extension = _item.Extension();
    using namespace std::string_view_literals;
    return "app"sv == extension;
}

bool IconBuilderImpl::ShouldTryProducingBundleIconOnVFS(const VFSListingItem &_item) const
{
    return MightBeBundle(_item);
}

} // namespace nc::vfsicon
