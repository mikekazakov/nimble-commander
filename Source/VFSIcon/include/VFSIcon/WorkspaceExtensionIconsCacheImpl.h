// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <Base/spinlock.h>
#include "WorkspaceExtensionIconsCache.h"
#include <Utility/UTI.h>
#include <Base/UnorderedUtil.h>

namespace nc::vfsicon {

class WorkspaceExtensionIconsCacheImpl : public WorkspaceExtensionIconsCache
{
public:
    WorkspaceExtensionIconsCacheImpl(const nc::utility::UTIDB &_uti_db);
    ~WorkspaceExtensionIconsCacheImpl();

    NSImage *CachedIconForExtension(const std::string &_extension) const override;
    NSImage *IconForExtension(const std::string &_extension) override;

    NSImage *GenericFileIcon() const override;
    NSImage *GenericFolderIcon() const override;

private:
    using IconsStorage =
        ankerl::unordered_dense::map<std::string, NSImage *, UnorderedStringHashEqual, UnorderedStringHashEqual>;

    NSImage *Find_Locked(const std::string &_extension) const;
    void Commit_Locked(const std::string &_extension, NSImage *_image);

    IconsStorage m_Icons;
    mutable spinlock m_Lock;
    NSImage *m_GenericFileIcon;
    NSImage *m_GenericFolderIcon;
    const nc::utility::UTIDB &m_UTIDB;
};

} // namespace nc::vfsicon
