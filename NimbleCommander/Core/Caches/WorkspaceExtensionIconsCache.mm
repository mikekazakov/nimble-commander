#include "WorkspaceExtensionIconsCache.h"

WorkspaceExtensionIconsCache::WorkspaceExtensionIconsCache()
{
    m_GenericFolderIcon = [NSImage imageNamed:NSImageNameFolder];
    m_GenericFileIcon = [NSWorkspace.sharedWorkspace iconForFileType:
        NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
}

WorkspaceExtensionIconsCache& WorkspaceExtensionIconsCache::Instance()
{
    static const auto i = new WorkspaceExtensionIconsCache;
    return *i;
}

NSImage *WorkspaceExtensionIconsCache::CachedIconForExtension( const string& _extension ) const
{
    return Find_Locked(_extension);
}

NSImage *WorkspaceExtensionIconsCache::Find_Locked( const string &_extension ) const
{
    if( _extension.empty() )
        return nil;
    
    LOCK_GUARD(m_Lock) {
        if( const auto i = m_Icons.find( _extension ); i != end(m_Icons) )
            return i->second;
    }
    return nil;
}

void WorkspaceExtensionIconsCache::Commit_Locked( const string &_extension, NSImage *_image)
{
    LOCK_GUARD(m_Lock) {
        m_Icons.emplace(_extension, _image);
    }
}

NSImage *WorkspaceExtensionIconsCache::IconForExtension( const string& _extension )
{
    if( _extension.empty() )
        return nil;
    
    if( const auto existing = Find_Locked(_extension) )
        return existing;

    const auto extension = [NSString stringWithUTF8StdString:_extension];
    const auto image = [NSWorkspace.sharedWorkspace iconForFileType:extension];
    Commit_Locked( _extension, image );
    
    return image;
}

NSImage *WorkspaceExtensionIconsCache::GenericFileIcon() const
{
    return m_GenericFileIcon;
}

NSImage *WorkspaceExtensionIconsCache::GenericFolderIcon() const
{
    return m_GenericFolderIcon;
}
