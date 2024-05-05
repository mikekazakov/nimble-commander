// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "DefaultAction.h"

namespace nc::config {
class Config;
}

namespace nc::panel::actions {

struct Duplicate final : PanelAction {
    Duplicate(nc::config::Config &_config);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    nc::config::Config &m_Config;
};

namespace context {

struct Duplicate final : PanelAction {
    Duplicate(nc::config::Config &_config, const std::vector<VFSListingItem> &_items);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    nc::config::Config &m_Config;
    const std::vector<VFSListingItem> &m_Items;
};

} // namespace context

} // namespace nc::panel::actions
