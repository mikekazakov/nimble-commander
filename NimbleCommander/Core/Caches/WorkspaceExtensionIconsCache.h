#pragma once

class WorkspaceExtensionIconsCache
{
public:
    static WorkspaceExtensionIconsCache& Instance();

    // may return nil if icon is generic
    NSImage *CachedIconForExtension( const string& _extension ) const;
    NSImage *IconForExtension( const string& _extension );

    NSImage *GenericFileIcon() const;
    NSImage *GenericFolderIcon() const;
    
private:
    WorkspaceExtensionIconsCache();
    bool IsEqualToDefault( NSImage *_img ) const;
    mutable spinlock                m_Lock;
    unordered_map<string, NSImage*> m_Icons;
    NSImage *m_GenericFileIcon;
    NSData  *m_GenericFileIconTIFF;
    NSImage *m_GenericFolderIcon;
    NSData  *m_GenericFolderIconTIFF;
};
