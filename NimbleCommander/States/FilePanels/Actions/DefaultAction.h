// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

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

struct StateAction
{
    virtual ~StateAction();
    virtual bool Predicate( MainWindowFilePanelState *_target ) const;
    virtual bool ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item ) const;
    virtual void Perform( MainWindowFilePanelState *_target, id _sender ) const;
};

};
