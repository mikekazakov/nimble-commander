#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

struct OpenFileWithSubmenu : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
};

struct AlwaysOpenFileWithSubmenu : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
};

}
