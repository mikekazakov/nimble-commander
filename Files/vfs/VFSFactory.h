#pragma once

#include "VFSDeclarations.h"

class VFSMeta
{
public:
    string                                                      Tag;
    function<VFSHostPtr(const VFSHostPtr &_parent,
                        const VFSConfiguration& _config,
                        VFSCancelChecker _cancel_checker)>      SpawnWithConfig; // may throw an exception upon call
};

class VFSFactory
{
public:
    static VFSFactory& Instance();
    
    const VFSMeta* Find(const string &_tag) const;
    const VFSMeta* Find(const char   *_tag) const;
    
    void RegisterVFS(VFSMeta _meta);
    
private:
    vector<VFSMeta> m_Metas;
};
