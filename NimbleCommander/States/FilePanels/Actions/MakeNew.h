#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace panel::actions {

struct MakeNewFile : DefaultPanelAction
{
    static bool Predicate( PanelController *_target );
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct MakeNewFolder : DefaultPanelAction
{
    static bool Predicate( PanelController *_target );
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct MakeNewNamedFolder : DefaultPanelAction
{
    static bool Predicate( PanelController *_target );
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

struct MakeNewFolderWithSelection : DefaultPanelAction
{
    static bool Predicate( PanelController *_target );
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

};
