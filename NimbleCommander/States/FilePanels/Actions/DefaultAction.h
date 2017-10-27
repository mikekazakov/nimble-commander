// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class PanelController;
@class MainWindowFilePanelState;

namespace nc::panel::actions {

struct PanelAction
{
    virtual ~PanelAction();
    virtual bool Predicate( PanelController *_target ) const;
    virtual bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const;
    virtual void Perform( PanelController *_target, id _sender ) const;
};

struct DefaultStateAction
{
    static bool Predicate( MainWindowFilePanelState *_target );
    static bool ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item );
    static void Perform( MainWindowFilePanelState *_target, id _sender );
};

};
