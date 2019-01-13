// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

class ExternalTool;

namespace nc::utility {
    class TemporaryFileStorage;
}

namespace nc::panel::actions {

struct ExecuteExternalTool : StateAction
{
    ExecuteExternalTool(nc::utility::TemporaryFileStorage &_temp_storage);
    void Perform( MainWindowFilePanelState *_target, id _sender ) const override;
private:
    void Execute(const ExternalTool &_tool, MainWindowFilePanelState *_target) const;
    nc::utility::TemporaryFileStorage &m_TempFileStorage;
};
    
}
