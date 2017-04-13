#include "DefaultAction.h"

namespace panel::actions {

bool PanelAction::Predicate( PanelController *_target )
{
    return true;
}

bool PanelAction::ValidateMenuItem( PanelController *_target, NSMenuItem *_item )
{
    return Predicate(_target);
}

void PanelAction::Perform( PanelController *_target, id _sender )
{
}

bool DefaultStateAction::Predicate( MainWindowFilePanelState *_target )
{
    return true;
}

bool DefaultStateAction::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item )
{
    return Predicate( _target );
}

void DefaultStateAction::Perform( MainWindowFilePanelState *_target, id _sender )
{
}

};
