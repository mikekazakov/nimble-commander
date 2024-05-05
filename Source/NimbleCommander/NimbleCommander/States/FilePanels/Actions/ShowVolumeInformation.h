// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::utility {
class NativeFSManager;
}

namespace nc::panel::actions {

struct ShowVolumeInformation final : PanelAction {
    ShowVolumeInformation(nc::utility::NativeFSManager &_nfsm);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    nc::utility::NativeFSManager &m_NativeFSManager;
};

}; // namespace nc::panel::actions
