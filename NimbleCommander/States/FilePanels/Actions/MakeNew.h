#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace panel::actions {

struct MakeNewFile : PanelAction
{
    bool Predicate( PanelController *_target );
    void Perform( PanelController *_target, id _sender );
};

struct MakeNewFolder : PanelAction
{
    bool Predicate( PanelController *_target );
    void Perform( PanelController *_target, id _sender );
};

struct MakeNewNamedFolder : PanelAction
{
    bool Predicate( PanelController *_target );
    void Perform( PanelController *_target, id _sender );
};

struct MakeNewFolderWithSelection : PanelAction
{
    bool Predicate( PanelController *_target );
    void Perform( PanelController *_target, id _sender );
};

};
