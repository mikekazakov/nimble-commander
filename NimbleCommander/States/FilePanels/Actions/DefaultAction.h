#pragma once

@class PanelController;
@class MainWindowFilePanelState;

namespace panel::actions {

struct PanelAction
{
    virtual bool Predicate( PanelController *_target );
    virtual bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    virtual void Perform( PanelController *_target, id _sender );
};

struct DefaultStateAction
{
    static bool Predicate( MainWindowFilePanelState *_target );
    static bool ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item );
    static void Perform( MainWindowFilePanelState *_target, id _sender );
};

};
