// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <unordered_map>
#include <Habanero/spinlock.h>
#include "WorkspaceExtensionIconsCache.h"

namespace nc::vfsicon {

class WorkspaceExtensionIconsCacheImpl : public WorkspaceExtensionIconsCache 
{
public:
    WorkspaceExtensionIconsCacheImpl();
    ~WorkspaceExtensionIconsCacheImpl();
    
    NSImage *CachedIconForExtension( const std::string& _extension ) const override;
    NSImage *IconForExtension( const std::string& _extension ) override;

    NSImage *GenericFileIcon() const override;
    NSImage *GenericFolderIcon() const override;
    
private:
    NSImage *Find_Locked( const std::string &_extension ) const;
    void Commit_Locked( const std::string &_extension, NSImage *_image);
    std::unordered_map<std::string, NSImage*> m_Icons;
    mutable spinlock                m_Lock;    
    NSImage *m_GenericFileIcon;
    NSImage *m_GenericFolderIcon;
};

}
