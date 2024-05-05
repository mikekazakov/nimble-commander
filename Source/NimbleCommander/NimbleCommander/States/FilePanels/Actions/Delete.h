// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "DefaultAction.h"

namespace nc::utility {
class NativeFSManager;
}

namespace nc::panel::actions {

struct Delete final : PanelAction {
    Delete(nc::utility::NativeFSManager &_nat_fsman, bool _permanently = false);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    nc::utility::NativeFSManager &m_NativeFSManager;
    bool m_Permanently;
};

struct MoveToTrash final : PanelAction {
    MoveToTrash(nc::utility::NativeFSManager &_nat_fsman);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    nc::utility::NativeFSManager &m_NativeFSManager;
};

namespace context {

struct DeletePermanently final : PanelAction {
    DeletePermanently(const std::vector<VFSListingItem> &_items);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    const std::vector<VFSListingItem> &m_Items;
    bool m_AllWriteable;
};

struct MoveToTrash final : PanelAction {
    MoveToTrash(const std::vector<VFSListingItem> &_items);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    const std::vector<VFSListingItem> &m_Items;
    bool m_AllAreNative;
};

} // namespace context

} // namespace nc::panel::actions
