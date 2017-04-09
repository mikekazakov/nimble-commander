#include "DefaultAction.h"

namespace panel::actions {

bool DefaultAction::Predicate( PanelController *_target )
{
    return true;
}

bool DefaultAction::ValidateMenuItem( PanelController *_target, NSMenuItem *_item )
{
    return Predicate( _target );
}

void DefaultAction::Perform( PanelController *_target, id _sender )
{
}

};
