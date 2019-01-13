// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

struct Enter final : PanelAction
{
    Enter(bool _support_archives, const PanelAction &_open_files_action);
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const bool m_SupportArchives;
    const PanelAction &m_OpenFilesAction;
};

}
