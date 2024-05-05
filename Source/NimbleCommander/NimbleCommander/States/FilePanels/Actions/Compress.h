// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "DefaultAction.h"

namespace nc::config {
class Config;
}

namespace nc::ops {
class Operation;
}

namespace nc::panel::actions {

class CompressBase
{
public:
    CompressBase(nc::config::Config &_config);

protected:
    void AddDeselectorIfNeeded(nc::ops::Operation &_with_operation, PanelController *_to_target) const;

private:
    bool ShouldAutomaticallyDeselect() const;

    nc::config::Config &m_Config;
};

struct CompressHere final : PanelAction, CompressBase {
    CompressHere(nc::config::Config &_config);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

struct CompressToOpposite final : PanelAction, CompressBase {
    CompressToOpposite(nc::config::Config &_config);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;
};

namespace context {

struct CompressHere final : PanelAction, CompressBase {
    CompressHere(nc::config::Config &_config, const std::vector<VFSListingItem> &_items);
    bool Predicate(PanelController *_target) const override;
    bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    const std::vector<VFSListingItem> &m_Items;
};

struct CompressToOpposite final : PanelAction, CompressBase {
    CompressToOpposite(nc::config::Config &_config, const std::vector<VFSListingItem> &_items);
    bool Predicate(PanelController *_target) const override;
    bool ValidateMenuItem(PanelController *_target, NSMenuItem *_item) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    const std::vector<VFSListingItem> &m_Items;
};

} // namespace context

} // namespace nc::panel::actions
