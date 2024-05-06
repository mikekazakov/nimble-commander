// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

@class MainWindowFilePanelState;

namespace nc::panel::actions {

class FocusLeftPanel final : public StateAction
{
public:
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
};

class FocusRightPanel final : public StateAction
{
public:
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
};

} // namespace nc::panel::actions
