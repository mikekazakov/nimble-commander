// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

class ExternalTool;

namespace nc::panel::actions {

struct ExecuteExternalTool : StateAction
{
    void Perform( MainWindowFilePanelState *_target, id _sender ) const override;
private:
    void Execute(const ExternalTool &_tool, MainWindowFilePanelState *_target) const;
};
    
}
