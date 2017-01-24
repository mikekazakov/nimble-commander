#include "WorkspaceExtensionIconsCache.h"

WorkspaceExtensionIconsCache::WorkspaceExtensionIconsCache()
{
    m_GenericFolderIcon = [NSImage imageNamed:NSImageNameFolder];
    m_GenericFileIconTIFF = m_GenericFolderIcon.TIFFRepresentation;
    m_GenericFileIcon = [NSWorkspace.sharedWorkspace iconForFileType:
        NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
    m_GenericFileIconTIFF = m_GenericFileIcon.TIFFRepresentation;
}

WorkspaceExtensionIconsCache& WorkspaceExtensionIconsCache::Instance()
{
    static
    const auto i = new WorkspaceExtensionIconsCache;
    return *i;
}

NSImage *WorkspaceExtensionIconsCache::CachedIconForExtension( const string& _extension ) const
{
    LOCK_GUARD(m_Lock) {
        auto i = m_Icons.find( _extension );
        if( i != end(m_Icons) )
            return i->second;
    }
    return nil;
}

NSImage *WorkspaceExtensionIconsCache::IconForExtension( const string& _extension )
{
    LOCK_GUARD(m_Lock) {
        auto i = m_Icons.find( _extension );
        if( i != end(m_Icons) )
            return i->second;
    }
    
    const auto e = [NSString stringWithUTF8StdStringNoCopy:_extension];
    const auto image = [NSWorkspace.sharedWorkspace iconForFileType:e];
    const auto is_default = IsEqualToDefault(image);
    LOCK_GUARD(m_Lock) {
        m_Icons.emplace(_extension, !is_default ? image : nil);
    }
    return !is_default ? image : nil;
}

NSImage *WorkspaceExtensionIconsCache::GenericFileIcon() const
{
    return m_GenericFileIcon;
}

NSImage *WorkspaceExtensionIconsCache::GenericFolderIcon() const
{
    return m_GenericFolderIcon;
}

bool WorkspaceExtensionIconsCache::IsEqualToDefault( NSImage *_img ) const
{
    auto tiff = _img.TIFFRepresentation;
    return [tiff isEqualToData:m_GenericFileIconTIFF] ||
           [tiff isEqualToData:m_GenericFolderIconTIFF];
}
