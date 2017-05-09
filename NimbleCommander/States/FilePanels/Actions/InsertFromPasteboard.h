#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

// extract additional state from NSPasteboard.generalPasteboard

struct PasteFromPasteboard : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct MoveFromPasteboard : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

};
