// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <vector>
#include <string>
#include "VFSDeclarations.h"

class VFSMeta
{
public:
    std::string                                                      Tag;
    std::function<VFSHostPtr(const VFSHostPtr &_parent,
                             const VFSConfiguration& _config,
                             VFSCancelChecker _cancel_checker)>      SpawnWithConfig; // may throw an exception upon call
};

class VFSFactory
{
public:
    static VFSFactory& Instance();
    
    const VFSMeta* Find(const std::string &_tag) const;
    const VFSMeta* Find(const char   *_tag) const;
    
    void RegisterVFS(VFSMeta _meta);
    
private:
    std::vector<VFSMeta> m_Metas;
};
