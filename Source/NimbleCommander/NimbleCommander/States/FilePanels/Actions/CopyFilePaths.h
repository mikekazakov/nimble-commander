// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"
#include <VFS/VFS.h>

namespace nc::panel::actions {

struct CopyFileName final : PanelAction {
    [[nodiscard]] bool Predicate(PanelController *_source) const override;
    void Perform(PanelController *_source, id _sender) const override;
};

struct CopyFilePath final : PanelAction {
    [[nodiscard]] bool Predicate(PanelController *_source) const override;
    void Perform(PanelController *_source, id _sender) const override;
};

struct CopyFileDirectory final : PanelAction {
    [[nodiscard]] bool Predicate(PanelController *_source) const override;
    void Perform(PanelController *_source, id _sender) const override;
};

namespace context {

struct CopyPathname final : PanelAction {
    explicit CopyPathname(const std::vector<VFSListingItem> &_items);
    [[nodiscard]] bool Predicate(PanelController *_source) const override;
    [[nodiscard]] bool ValidateMenuItem(PanelController *_source, NSMenuItem *_item) const override;
    void Perform(PanelController *_source, id _sender) const override;

private:
    const std::vector<VFSListingItem> &m_Items;
};

} // namespace context

} // namespace nc::panel::actions
