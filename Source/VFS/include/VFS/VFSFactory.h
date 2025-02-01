// Copyright (C) 2016-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <vector>
#include <string>
#include <Base/Error.h>
#include "VFSDeclarations.h"

// TODO: move into a namespace

class VFSMeta
{
public:
    std::string Tag;
    std::function<VFSHostPtr(const VFSHostPtr &_parent,
                             const VFSConfiguration &_config,
                             VFSCancelChecker _cancel_checker)>
        SpawnWithConfig; // may throw an exception upon call

    // The description provider for this VFS will be automatically registered with nc::Error once it is passed into
    // RegisterVFS().
    std::string error_domain;
    std::shared_ptr<const nc::base::ErrorDescriptionProvider> error_description_provider;
};

class VFSFactory
{
public:
    static VFSFactory &Instance();

    const VFSMeta *Find(const std::string &_tag) const;
    const VFSMeta *Find(const char *_tag) const;

    void RegisterVFS(VFSMeta _meta);

private:
    std::vector<VFSMeta> m_Metas;
};
