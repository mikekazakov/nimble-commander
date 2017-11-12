// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DefaultAction.h"

namespace nc::panel::actions {

PanelAction::~PanelAction()
{
}

bool PanelAction::Predicate( PanelController *_target ) const
{
    return true;
}

bool PanelAction::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    return Predicate(_target);
}

void PanelAction::Perform( PanelController *_target, id _sender ) const
{
}

StateAction::~StateAction()
{
}

bool StateAction::Predicate( MainWindowFilePanelState *_target ) const
{
    return true;
}

bool StateAction::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item ) const
{
    return Predicate( _target );
}

void StateAction::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
}

};
