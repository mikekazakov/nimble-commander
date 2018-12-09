// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "VFSInstancePromise.h"
#include "VFSInstanceManager.h"

namespace nc::core {

static_assert( sizeof(VFSInstancePromise) == 16, "" );

VFSInstancePromise::VFSInstancePromise():
    inst_id(0),
    manager(nullptr)
{
}

VFSInstancePromise::VFSInstancePromise(uint64_t _inst_id, VFSInstanceManager &_manager):
    inst_id(_inst_id),
    manager(&_manager)
{ /* here assumes that producing manager will perform initial increment himself. */}

VFSInstancePromise::~VFSInstancePromise()
{
    if(manager)
        manager->DecPromiseCount(inst_id);
}

VFSInstancePromise::VFSInstancePromise(VFSInstancePromise &&_rhs):
    inst_id(_rhs.inst_id),
    manager(_rhs.manager)
{
    _rhs.inst_id = 0;
    _rhs.manager = nullptr;
}

VFSInstancePromise::VFSInstancePromise(const VFSInstancePromise &_rhs):
    inst_id(_rhs.inst_id),
    manager(_rhs.manager)
{
    if(manager)
        manager->IncPromiseCount(inst_id);
}

const VFSInstancePromise& VFSInstancePromise::operator=(const VFSInstancePromise &_rhs)
{
    if(manager)
        manager->DecPromiseCount(inst_id);
    inst_id = _rhs.inst_id;
    manager = _rhs.manager;
    if(manager)
        manager->IncPromiseCount(inst_id);
    return *this;
}

const VFSInstancePromise& VFSInstancePromise::operator=(VFSInstancePromise &&_rhs)
{
    if(manager)
        manager->DecPromiseCount(inst_id);
    inst_id = _rhs.inst_id;
    manager = _rhs.manager;
    _rhs.inst_id = 0;
    _rhs.manager = nullptr;
    return *this;
}

VFSInstancePromise::operator bool() const noexcept
{
    return manager != nullptr && inst_id != 0;
}

bool VFSInstancePromise::operator ==(const VFSInstancePromise &_rhs) const noexcept
{
    return manager == _rhs.manager && inst_id == _rhs.inst_id;
}

bool VFSInstancePromise::operator !=(const VFSInstancePromise &_rhs) const noexcept
{
    return !(*this == _rhs);
}

const char *VFSInstancePromise::tag() const
{
    return manager ? manager->GetTag(*this) : "";
}

uint64_t VFSInstancePromise::id() const
{
    return inst_id;
}

std::string VFSInstancePromise::verbose_title() const
{
    return manager ? manager->GetVerboseVFSTitle(*this) : "";
}

}
