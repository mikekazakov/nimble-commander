// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Host.h"
namespace nc::vfs {

const char *MemHost::UniqueTag = "memfs";

class VFSMemHostConfiguration
{
public:
    [[nodiscard]] static const char *Tag() { return MemHost::UniqueTag; }

    [[nodiscard]] static const char *Junction() { return ""; }

    bool operator==(const VFSMemHostConfiguration & /*unused*/) const { return true; }

    [[nodiscard]] static const char *VerboseJunction() { return "[memfs]:"; }
};

MemHost::MemHost() : Host("", std::shared_ptr<Host>(nullptr), UniqueTag)
{
}
MemHost::~MemHost() = default;

VFSConfiguration MemHost::Configuration() const
{
    static auto c = VFSMemHostConfiguration();
    return c;
}

VFSMeta MemHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = []([[maybe_unused]] const VFSHostPtr &_parent,
                           [[maybe_unused]] const VFSConfiguration &_config,
                           [[maybe_unused]] VFSCancelChecker _cancel_checker) { return std::make_shared<MemHost>(); };
    return m;
}

} // namespace nc::vfs
