// Copyright (C) 2018-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::bootstrap {
class ActivationManager;
}

namespace nc::utility {
class TemporaryFileStorage;
}

namespace nc::panel {
class ExternalTool;
}

namespace nc::panel::actions {

struct ExecuteExternalTool : StateAction {
    ExecuteExternalTool(nc::utility::TemporaryFileStorage &_temp_storage, nc::bootstrap::ActivationManager &_ac);
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;

private:
    void Execute(const ExternalTool &_tool, MainWindowFilePanelState *_target) const;
    nc::utility::TemporaryFileStorage &m_TempFileStorage;
    nc::bootstrap::ActivationManager &m_ActivationManager;
};

} // namespace nc::panel::actions
