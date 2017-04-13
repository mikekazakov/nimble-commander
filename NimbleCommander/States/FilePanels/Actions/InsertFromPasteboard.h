#pragma once

#include "DefaultAction.h"

namespace panel::actions {

// extract additional state from NSPasteboard.generalPasteboard

struct PasteFromPasteboard : PanelAction
{
    bool Predicate( PanelController *_target );
    void Perform( PanelController *_target, id _sender );
};

struct MoveFromPasteboard : PanelAction
{
    bool Predicate( PanelController *_target );
    void Perform( PanelController *_target, id _sender );
};

};
