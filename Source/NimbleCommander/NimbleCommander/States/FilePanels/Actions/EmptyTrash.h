#pragma once

#include "DefaultAction.h"
#include <Utility/NativeFSManager.h>

namespace nc::utility { class NativeFSManager; }

namespace nc::panel::actions {

struct EmptyTrash final : PanelAction {
    EmptyTrash(nc::utility::NativeFSManager &_nat_fsman);
    [[nodiscard]] bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;
    NSURL *CurrentTrashURL(PanelController *_target) const;
    NSArray<NSURL *> *TrashFilePaths(PanelController *_target) const;

private:
    nc::utility::NativeFSManager &m_NativeFSManager;
};

} // namespace nc::panel::actions
