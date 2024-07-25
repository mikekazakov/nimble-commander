// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <stdint.h>

namespace nc::core {

class VFSInstanceManager;

class VFSInstancePromise
{
public:
    VFSInstancePromise();
    VFSInstancePromise(VFSInstancePromise &&_rhs) noexcept;
    VFSInstancePromise(const VFSInstancePromise &_rhs);
    ~VFSInstancePromise();
    VFSInstancePromise &operator=(const VFSInstancePromise &_rhs);
    VFSInstancePromise &operator=(VFSInstancePromise &&_rhs) noexcept;
    operator bool() const noexcept;
    bool operator==(const VFSInstancePromise &_rhs) const noexcept;
    bool operator!=(const VFSInstancePromise &_rhs) const noexcept;
    const char *tag() const;           // may return ""
    std::string verbose_title() const; // may return ""
    uint64_t id() const;

private:
    VFSInstancePromise(uint64_t _inst_id, VFSInstanceManager &_manager);
    uint64_t inst_id;
    VFSInstanceManager *manager; // non-owning pointer, promises must not outlive the manager
    friend class VFSInstanceManager;
};

} // namespace nc::core
