// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/Host.h>
#include <VFS/VFSFile.h>

namespace nc::vfs {

// This is a stub for something I need to write

class MemHost : public Host
{
public:
    MemHost();
    ~MemHost();

    static const char *UniqueTag;
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
};

} // namespace nc::vfs
