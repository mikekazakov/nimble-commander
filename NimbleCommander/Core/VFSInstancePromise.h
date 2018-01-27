// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::core {

class VFSInstanceManager;

class VFSInstancePromise
{
public:
    VFSInstancePromise();
    VFSInstancePromise(VFSInstancePromise &&_rhs);
    VFSInstancePromise(const VFSInstancePromise &_rhs);
    ~VFSInstancePromise();
    const VFSInstancePromise& operator=(const VFSInstancePromise &_rhs);
    const VFSInstancePromise& operator=(VFSInstancePromise &&_rhs);
    operator bool() const noexcept;
    bool operator ==(const VFSInstancePromise &_rhs) const noexcept;
    bool operator !=(const VFSInstancePromise &_rhs) const noexcept;
    const char *tag() const; // may return ""
    string verbose_title() const; // may return ""
    uint64_t id() const;
private:
    VFSInstancePromise(uint64_t _inst_id, VFSInstanceManager &_manager);
    uint64_t            inst_id;
    VFSInstanceManager *manager; // non-owning pointer, promises must not outlive the manager
    friend class VFSInstanceManager;
};

}
