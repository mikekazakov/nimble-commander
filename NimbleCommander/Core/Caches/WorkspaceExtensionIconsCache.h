// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::core {

class WorkspaceExtensionIconsCache
{
public:
    static WorkspaceExtensionIconsCache& Instance();

    NSImage *CachedIconForExtension( const string& _extension ) const;
    NSImage *IconForExtension( const string& _extension );

    NSImage *GenericFileIcon() const noexcept;
    NSImage *GenericFolderIcon() const noexcept;
    
private:
    WorkspaceExtensionIconsCache();
    NSImage *Find_Locked( const string &_extension ) const;
    void Commit_Locked( const string &_extension, NSImage *_image);
    mutable spinlock                m_Lock;
    unordered_map<string, NSImage*> m_Icons;
    NSImage *m_GenericFileIcon;
    NSImage *m_GenericFolderIcon;
};

}
