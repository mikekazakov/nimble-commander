// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DefaultAction.h"

namespace nc::panel::actions {

PanelAction::~PanelAction()
{
}

bool PanelAction::Predicate( PanelController * ) const
{
    return true;
}

bool PanelAction::ValidateMenuItem( PanelController *_target, NSMenuItem * ) const
{
    return Predicate(_target);
}

void PanelAction::Perform( PanelController *, id  ) const
{
}

StateAction::~StateAction()
{
}

bool StateAction::Predicate( MainWindowFilePanelState * ) const
{
    return true;
}

bool StateAction::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem * ) const
{
    return Predicate( _target );
}

void StateAction::Perform( MainWindowFilePanelState *, id ) const
{
}

};
