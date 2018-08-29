// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <unordered_map>
#include <Habanero/spinlock.h>

@class NSImage;

namespace nc::utility {

class WorkspaceExtensionIconsCache
{
public:
//    static WorkspaceExtensionIconsCache& Instance();
    WorkspaceExtensionIconsCache();
    
    NSImage *CachedIconForExtension( const std::string& _extension ) const;
    NSImage *IconForExtension( const std::string& _extension );

    NSImage *GenericFileIcon() const noexcept;
    NSImage *GenericFolderIcon() const noexcept;
    
private:
    NSImage *Find_Locked( const std::string &_extension ) const;
    void Commit_Locked( const std::string &_extension, NSImage *_image);
    mutable spinlock                m_Lock;
    std::unordered_map<std::string, NSImage*> m_Icons;
    NSImage *m_GenericFileIcon;
    NSImage *m_GenericFolderIcon;
};

}
