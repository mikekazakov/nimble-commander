// Copyright (C) 2016-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/VFS/VFSFactory.h"

VFSFactory &VFSFactory::Instance()
{
    static auto f = new VFSFactory;
    return *f;
}

void VFSFactory::RegisterVFS(VFSMeta _meta)
{
    if( !_meta.error_domain.empty() && _meta.error_description_provider ) {
        nc::Error::DescriptionProvider(_meta.error_domain, _meta.error_description_provider);
    }
    m_Metas.emplace_back(std::move(_meta));
}

const VFSMeta *VFSFactory::Find(const std::string &_tag) const
{
    for( auto &i : m_Metas )
        if( i.Tag == _tag )
            return &i;
    return nullptr;
}

const VFSMeta *VFSFactory::Find(const char *_tag) const
{
    if( _tag == nullptr )
        return nullptr;
    for( auto &i : m_Metas )
        if( i.Tag == _tag )
            return &i;
    return nullptr;
}
