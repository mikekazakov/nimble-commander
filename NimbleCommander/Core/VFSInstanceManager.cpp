// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "VFSInstanceManager.h"
#include "VFSInstancePromise.h"

namespace nc::core {

VFSInstanceManager::Promise VFSInstanceManager::SpawnPromise(uint64_t _inst_id)
{
    return Promise{_inst_id, *this};
}
    
VFSInstanceManager *VFSInstanceManager::InstanceFromPromise(const Promise& _promise)
{
    return _promise.manager;
}
    
}
